import type { Expr, Program, Slice, Stmt } from "./ast";
import { callBuiltin, callListMethod, callStringMethod } from "./builtins";
import type { FunctionDefNode, PyValue, Step, TraceResult } from "./types";
import {
  RuntimeErrorSignal,
  binOp,
  cloneVars,
  compareOp,
  isInstance,
  normalizeIndex,
  num,
  pySlice,
  pyStr,
  truthy,
} from "./values";

const MAX_STEPS = 5000;

const BUILTIN_NAMES = new Set([
  "print", "len", "range", "min", "max", "sum", "abs", "floor", "ceil", "sqrt", "pow",
  "round", "sorted", "list", "int", "float", "str", "bool", "enumerate", "zip", "reversed",
]);

class ReturnSignal {
  constructor(public value: PyValue) {}
}
class BreakSignal {
  readonly kind = "break" as const;
}
class ContinueSignal {
  readonly kind = "continue" as const;
}

interface Frame {
  vars: Record<string, PyValue>;
  funcName: string;
}

interface InterpCtx {
  functions: Map<string, FunctionDefNode>;
  classNames: Set<string>;
  output: string[];
  stepCount: number;
  floorMod: boolean;
}

function bumpStep(ctx: InterpCtx): void {
  ctx.stepCount++;
  if (ctx.stepCount > MAX_STEPS) {
    throw new RuntimeErrorSignal("Step limit reached — possible infinite loop", -1);
  }
}

function snapshot(line: number, frame: Frame, ctx: InterpCtx): Step {
  return { line, func: frame.funcName, locals: cloneVars(frame.vars), outputLen: ctx.output.length };
}

function toIterable(v: PyValue, line: number): PyValue[] {
  if (Array.isArray(v)) return v;
  if (typeof v === "string") return v.split("");
  throw new RuntimeErrorSignal("TypeError: value is not iterable", line);
}

function checkArity(fn: FunctionDefNode, args: PyValue[], line: number): void {
  if (args.length === fn.params.length) return;
  if (args.length < fn.params.length) {
    throw new RuntimeErrorSignal(
      `TypeError: ${fn.name}() missing ${fn.params.length - args.length} required positional argument(s)`,
      line,
    );
  }
  throw new RuntimeErrorSignal(
    `TypeError: ${fn.name}() takes ${fn.params.length} positional argument(s) but ${args.length} were given`,
    line,
  );
}

function* callFunction(fn: FunctionDefNode, args: PyValue[], ctx: InterpCtx, line: number): Generator<Step, PyValue, void> {
  checkArity(fn, args, line);
  const newFrame: Frame = { vars: {}, funcName: fn.name };
  fn.params.forEach((p, i) => {
    newFrame.vars[p] = args[i];
  });
  try {
    yield* execBlock(fn.body, newFrame, ctx);
  } catch (e) {
    if (e instanceof ReturnSignal) return e.value;
    throw e;
  }
  return null;
}

function bindTarget(target: Expr, value: PyValue, frame: Frame, line: number): void {
  if (target.type === "TupleExpr") {
    if (!Array.isArray(value)) throw new RuntimeErrorSignal("cannot unpack non-iterable value", line);
    if (value.length !== target.elements.length) {
      throw new RuntimeErrorSignal(
        `ValueError: too ${value.length > target.elements.length ? "many" : "few"} values to unpack`,
        line,
      );
    }
    target.elements.forEach((t, i) => bindTarget(t, value[i], frame, line));
    return;
  }
  if (target.type === "Name") {
    frame.vars[target.id] = value;
    return;
  }
  throw new RuntimeErrorSignal("invalid assignment target", line);
}

function* assignTo(target: Expr, value: PyValue, frame: Frame, ctx: InterpCtx, line: number): Generator<Step, void, void> {
  if (target.type === "Subscript") {
    const obj = yield* evalExpr(target.obj, frame, ctx);
    if (!Array.isArray(obj)) throw new RuntimeErrorSignal("TypeError: object does not support item assignment", line);
    if (target.index.type === "Slice") throw new RuntimeErrorSignal("slice assignment not supported", line);
    const idxVal = yield* evalExpr(target.index, frame, ctx);
    const i = normalizeIndex(obj.length, num(idxVal, line), line);
    obj[i] = value;
    return;
  }
  if (target.type === "TupleExpr") {
    if (!Array.isArray(value)) throw new RuntimeErrorSignal("cannot unpack non-iterable value", line);
    if (value.length !== target.elements.length) {
      throw new RuntimeErrorSignal(
        `ValueError: too ${value.length > target.elements.length ? "many" : "few"} values to unpack`,
        line,
      );
    }
    for (let i = 0; i < target.elements.length; i++) {
      yield* assignTo(target.elements[i], value[i], frame, ctx, line);
    }
    return;
  }
  bindTarget(target, value, frame, line);
}

function* execProgram(program: Program, ctx: InterpCtx): Generator<Step, void, void> {
  const moduleFrame: Frame = { vars: {}, funcName: "<module>" };
  try {
    yield* execBlock(program.body, moduleFrame, ctx);
  } catch (e) {
    if (e instanceof ReturnSignal) return;
    throw e;
  }
}

function* execBlock(stmts: Stmt[], frame: Frame, ctx: InterpCtx): Generator<Step, void, void> {
  for (const stmt of stmts) {
    yield* execStmt(stmt, frame, ctx);
  }
}

function* execStmt(stmt: Stmt, frame: Frame, ctx: InterpCtx): Generator<Step, void, void> {
  switch (stmt.type) {
    case "FunctionDef":
      return;
    case "Pass":
      bumpStep(ctx);
      yield snapshot(stmt.line, frame, ctx);
      return;
    case "Break":
      bumpStep(ctx);
      yield snapshot(stmt.line, frame, ctx);
      throw new BreakSignal();
    case "Continue":
      bumpStep(ctx);
      yield snapshot(stmt.line, frame, ctx);
      throw new ContinueSignal();
    case "Return": {
      bumpStep(ctx);
      yield snapshot(stmt.line, frame, ctx);
      const val = stmt.value ? yield* evalExpr(stmt.value, frame, ctx) : null;
      throw new ReturnSignal(val);
    }
    case "ExprStmt": {
      bumpStep(ctx);
      yield snapshot(stmt.line, frame, ctx);
      yield* evalExpr(stmt.expr, frame, ctx);
      return;
    }
    case "Assign": {
      bumpStep(ctx);
      yield snapshot(stmt.line, frame, ctx);
      const val = yield* evalExpr(stmt.value, frame, ctx);
      yield* assignTo(stmt.target, val, frame, ctx, stmt.line);
      return;
    }
    case "AugAssign": {
      bumpStep(ctx);
      yield snapshot(stmt.line, frame, ctx);
      const current = yield* evalExpr(stmt.target, frame, ctx);
      const rhs = yield* evalExpr(stmt.value, frame, ctx);
      const next = binOp(stmt.op, current, rhs, ctx.floorMod, stmt.line);
      yield* assignTo(stmt.target, next, frame, ctx, stmt.line);
      return;
    }
    case "If": {
      bumpStep(ctx);
      yield snapshot(stmt.line, frame, ctx);
      const cond = yield* evalExpr(stmt.test, frame, ctx);
      yield* execBlock(truthy(cond) ? stmt.body : stmt.orelse, frame, ctx);
      return;
    }
    case "While": {
      for (;;) {
        bumpStep(ctx);
        yield snapshot(stmt.line, frame, ctx);
        const cond = yield* evalExpr(stmt.test, frame, ctx);
        if (!truthy(cond)) return;
        try {
          yield* execBlock(stmt.body, frame, ctx);
        } catch (e) {
          if (e instanceof ContinueSignal) continue;
          if (e instanceof BreakSignal) return;
          throw e;
        }
      }
    }
    case "For": {
      const iterVal = yield* evalExpr(stmt.iter, frame, ctx);
      const items = toIterable(iterVal, stmt.line);
      for (const item of items) {
        bindTarget(stmt.target, item, frame, stmt.line);
        bumpStep(ctx);
        yield snapshot(stmt.line, frame, ctx);
        try {
          yield* execBlock(stmt.body, frame, ctx);
        } catch (e) {
          if (e instanceof ContinueSignal) continue;
          if (e instanceof BreakSignal) break;
          throw e;
        }
      }
      return;
    }
  }
}

function* evalExpr(node: Expr, frame: Frame, ctx: InterpCtx): Generator<Step, PyValue, void> {
  switch (node.type) {
    case "Literal":
      return node.value;
    case "Name": {
      if (Object.prototype.hasOwnProperty.call(frame.vars, node.id)) return frame.vars[node.id];
      throw new RuntimeErrorSignal(`NameError: name '${node.id}' is not defined`, node.line);
    }
    case "ListLiteral": {
      const out: PyValue[] = [];
      for (const el of node.elements) out.push(yield* evalExpr(el, frame, ctx));
      return out;
    }
    case "TupleExpr": {
      const out: PyValue[] = [];
      for (const el of node.elements) out.push(yield* evalExpr(el, frame, ctx));
      return out;
    }
    case "FString": {
      let out = "";
      for (const part of node.parts) {
        out += part.kind === "text" ? part.value : pyStr(yield* evalExpr(part.expr, frame, ctx));
      }
      return out;
    }
    case "UnaryOp": {
      const v = yield* evalExpr(node.operand, frame, ctx);
      if (node.op === "-") return -num(v, node.line);
      if (node.op === "+") return num(v, node.line);
      if (node.op === "not") return !truthy(v);
      throw new RuntimeErrorSignal(`unsupported unary operator '${node.op}'`, node.line);
    }
    case "BinOp": {
      const l = yield* evalExpr(node.left, frame, ctx);
      const r = yield* evalExpr(node.right, frame, ctx);
      return binOp(node.op, l, r, ctx.floorMod, node.line);
    }
    case "BoolOp": {
      if (node.op === "and") {
        for (const v of node.values) {
          if (!truthy(yield* evalExpr(v, frame, ctx))) return false;
        }
        return true;
      }
      for (const v of node.values) {
        if (truthy(yield* evalExpr(v, frame, ctx))) return true;
      }
      return false;
    }
    case "Compare": {
      let left = yield* evalExpr(node.left, frame, ctx);
      for (let i = 0; i < node.ops.length; i++) {
        const right = yield* evalExpr(node.comparators[i], frame, ctx);
        if (!compareOp(node.ops[i], left, right, node.line)) return false;
        left = right;
      }
      return true;
    }
    case "Subscript": {
      const obj = yield* evalExpr(node.obj, frame, ctx);
      if (node.index.type === "Slice") {
        if (typeof obj !== "string" && !Array.isArray(obj)) {
          throw new RuntimeErrorSignal("TypeError: object is not subscriptable", node.line);
        }
        const slice = node.index as Slice;
        const lower = slice.lower ? num(yield* evalExpr(slice.lower, frame, ctx), node.line) : null;
        const upper = slice.upper ? num(yield* evalExpr(slice.upper, frame, ctx), node.line) : null;
        const step = slice.step ? num(yield* evalExpr(slice.step, frame, ctx), node.line) : null;
        return pySlice(obj, lower, upper, step);
      }
      const idxVal = yield* evalExpr(node.index, frame, ctx);
      if (typeof obj === "string") return obj[normalizeIndex(obj.length, num(idxVal, node.line), node.line)];
      if (Array.isArray(obj)) return obj[normalizeIndex(obj.length, num(idxVal, node.line), node.line)];
      throw new RuntimeErrorSignal("TypeError: object is not subscriptable", node.line);
    }
    case "Attribute":
      throw new RuntimeErrorSignal(`AttributeError: attribute access on '${node.attr}' is not supported here`, node.line);
    case "Call":
      return yield* evalCall(node, frame, ctx);
  }
}

function* evalArgs(args: Expr[], frame: Frame, ctx: InterpCtx): Generator<Step, PyValue[], void> {
  const out: PyValue[] = [];
  for (const a of args) out.push(yield* evalExpr(a, frame, ctx));
  return out;
}

function* evalCall(node: Extract<Expr, { type: "Call" }>, frame: Frame, ctx: InterpCtx): Generator<Step, PyValue, void> {
  const { callee } = node;

  if (callee.type === "Name") {
    const fname = callee.id;
    if (BUILTIN_NAMES.has(fname) && !ctx.functions.has(fname)) {
      const args = yield* evalArgs(node.args, frame, ctx);
      return callBuiltin(fname, args, ctx.output, node.line);
    }
    if (ctx.classNames.has(fname)) return { __instance_of__: fname };
    const fn = ctx.functions.get(fname);
    if (!fn) throw new RuntimeErrorSignal(`NameError: name '${fname}' is not defined`, node.line);
    const args = yield* evalArgs(node.args, frame, ctx);
    return yield* callFunction(fn, args, ctx, node.line);
  }

  if (callee.type === "Attribute") {
    const objVal = yield* evalExpr(callee.obj, frame, ctx);
    const method = callee.attr;
    const args = yield* evalArgs(node.args, frame, ctx);
    if (Array.isArray(objVal)) return callListMethod(objVal, method, args, node.line);
    if (typeof objVal === "string") return callStringMethod(objVal, method, args, node.line);
    if (isInstance(objVal)) {
      const fn = ctx.functions.get(method);
      if (!fn) {
        throw new RuntimeErrorSignal(`AttributeError: '${objVal.__instance_of__}' object has no attribute '${method}'`, node.line);
      }
      return yield* callFunction(fn, args, ctx, node.line);
    }
    throw new RuntimeErrorSignal(`TypeError: cannot call method '${method}' on this value`, node.line);
  }

  throw new RuntimeErrorSignal("TypeError: value is not callable", node.line);
}

export function runProgram(
  program: Program,
  functions: Map<string, FunctionDefNode>,
  classNames: Set<string>,
  floorMod: boolean,
): TraceResult {
  const ctx: InterpCtx = { functions, classNames, output: [], stepCount: 0, floorMod };
  const steps: Step[] = [];
  let error: string | null = null;
  try {
    const gen = execProgram(program, ctx);
    for (;;) {
      const result = gen.next();
      if (result.done) break;
      steps.push(result.value as Step);
    }
  } catch (e) {
    if (e instanceof RuntimeErrorSignal) {
      error = e.line >= 0 ? `${e.message} (line ${e.line})` : e.message;
    } else if (e instanceof Error) {
      error = e.message;
    } else {
      error = String(e);
    }
  }
  return { steps, output: ctx.output.join("\n"), outputLines: ctx.output, error };
}
