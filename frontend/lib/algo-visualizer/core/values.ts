import type { PyInstance, PyValue } from "./types";

export class RuntimeErrorSignal extends Error {
  constructor(
    message: string,
    public line: number,
  ) {
    super(message);
  }
}

export function isInstance(v: PyValue): v is PyInstance {
  return typeof v === "object" && v !== null && !Array.isArray(v) && "__instance_of__" in v;
}

export function num(v: PyValue, line: number): number {
  if (typeof v === "number") return v;
  if (typeof v === "boolean") return v ? 1 : 0;
  throw new RuntimeErrorSignal(`TypeError: unsupported operand type '${describeType(v)}'`, line);
}

export function describeType(v: PyValue): string {
  if (v === null) return "NoneType";
  if (Array.isArray(v)) return "list";
  if (isInstance(v)) return v.__instance_of__;
  return typeof v;
}

export function truthy(v: PyValue): boolean {
  if (v === null || v === false) return false;
  if (v === 0 || v === "") return false;
  if (Array.isArray(v) && v.length === 0) return false;
  return true;
}

export function pyStr(v: PyValue): string {
  if (v === null) return "None";
  if (v === true) return "True";
  if (v === false) return "False";
  if (typeof v === "string") return v;
  if (Array.isArray(v)) return `[${v.map(pyRepr).join(", ")}]`;
  if (isInstance(v)) return `<${v.__instance_of__} instance>`;
  return String(v);
}

export function pyRepr(v: PyValue): string {
  if (typeof v === "string") return `'${v}'`;
  return pyStr(v);
}

export function pyEquals(a: PyValue, b: PyValue): boolean {
  if (Array.isArray(a) && Array.isArray(b)) {
    return a.length === b.length && a.every((v, i) => pyEquals(v, b[i]));
  }
  return a === b;
}

export function compareOp(op: string, l: PyValue, r: PyValue, line: number): boolean {
  switch (op) {
    case "==":
      return pyEquals(l, r);
    case "!=":
      return !pyEquals(l, r);
    case "<":
    case "<=":
    case ">":
    case ">=": {
      const ln = typeof l === "string" ? l : num(l, line);
      const rn = typeof r === "string" ? r : num(r, line);
      if (op === "<") return ln < rn;
      if (op === "<=") return ln <= rn;
      if (op === ">") return ln > rn;
      return ln >= rn;
    }
    case "in":
      if (Array.isArray(r)) return r.some((v) => pyEquals(v, l));
      if (typeof r === "string" && typeof l === "string") return r.includes(l);
      throw new RuntimeErrorSignal(`TypeError: argument of type '${describeType(r)}' is not iterable`, line);
    case "not in":
      return !compareOp("in", l, r, line);
    default:
      throw new RuntimeErrorSignal(`unsupported comparison operator '${op}'`, line);
  }
}

export function binOp(op: string, l: PyValue, r: PyValue, floorMod: boolean, line: number): PyValue {
  switch (op) {
    case "+":
      if (Array.isArray(l) && Array.isArray(r)) return [...l, ...r];
      if (typeof l === "string" && typeof r === "string") return l + r;
      return num(l, line) + num(r, line);
    case "-":
      return num(l, line) - num(r, line);
    case "*":
      if (Array.isArray(l) && typeof r === "number") return repeat(l, r);
      if (typeof l === "string" && typeof r === "number") return l.repeat(Math.max(0, r));
      return num(l, line) * num(r, line);
    case "/": {
      const rn = num(r, line);
      if (rn === 0) throw new RuntimeErrorSignal("ZeroDivisionError: division by zero", line);
      return num(l, line) / rn;
    }
    case "//": {
      const rn = num(r, line);
      if (rn === 0) throw new RuntimeErrorSignal("ZeroDivisionError: division by zero", line);
      return Math.floor(num(l, line) / rn);
    }
    case "%": {
      const a = num(l, line);
      const b = num(r, line);
      if (b === 0) throw new RuntimeErrorSignal("ZeroDivisionError: modulo by zero", line);
      return floorMod ? a - Math.floor(a / b) * b : a % b;
    }
    case "**":
      return Math.pow(num(l, line), num(r, line));
    default:
      throw new RuntimeErrorSignal(`unsupported operator '${op}'`, line);
  }
}

function repeat(arr: PyValue[], n: number): PyValue[] {
  const out: PyValue[] = [];
  for (let i = 0; i < n; i++) out.push(...arr);
  return out;
}

export function normalizeIndex(len: number, i: number, line: number): number {
  let idx = Math.trunc(i);
  if (idx < 0) idx += len;
  if (idx < 0 || idx >= len) throw new RuntimeErrorSignal("IndexError: index out of range", line);
  return idx;
}

export function pySlice<T extends PyValue[] | string>(
  seq: T,
  lower: number | null,
  upper: number | null,
  step: number | null,
): T {
  const len = seq.length;
  const st = step ?? 1;
  const clamp = (n: number) => Math.max(0, Math.min(len, n < 0 ? n + len : n));
  const isStr = typeof seq === "string";
  const out: PyValue[] = [];
  if (st > 0) {
    const lo = clamp(lower ?? 0);
    const hi = clamp(upper ?? len);
    for (let i = lo; i < hi; i += st) out.push((seq as unknown as PyValue[])[i]);
  } else if (st < 0) {
    const lo = lower === null ? len - 1 : lower < 0 ? Math.max(-1, lower + len) : Math.min(len - 1, lower);
    const hi = upper === null ? -1 : upper < 0 ? Math.max(-1, upper + len) : Math.min(len - 1, upper);
    for (let i = lo; i > hi; i += st) {
      if (i < 0 || i >= len) break;
      out.push((seq as unknown as PyValue[])[i]);
    }
  }
  return (isStr ? out.join("") : out) as T;
}

export function cloneValue(v: PyValue): unknown {
  if (Array.isArray(v)) return v.map(cloneValue);
  if (isInstance(v)) return `<${v.__instance_of__} instance>`;
  return v;
}

export function cloneVars(vars: Record<string, PyValue>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const k in vars) out[k] = cloneValue(vars[k]);
  return out;
}
