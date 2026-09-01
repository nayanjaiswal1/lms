import type { Expr, FStringPart, Slice, Stmt } from "../../core/ast";
import type { FunctionDefNode, ParseResult } from "../../core/types";
import { ParseError } from "../../core/types";
import { type PyToken, type PyTokenType, tokenizePython } from "./lexer";

const AUG_OPS = new Set(["+=", "-=", "*=", "/=", "//=", "%=", "**="]);
const COMPARE_OPS = new Set(["==", "!=", "<", "<=", ">", ">="]);
const TERM_OPS = new Set(["*", "/", "//", "%"]);

function unescapeFStringText(s: string): string {
  return s.replace(/\\n/g, "\n").replace(/\\t/g, "\t").replace(/\\\\/g, "\\").replace(/\\'/g, "'").replace(/\\"/g, '"');
}

class PythonParser {
  private pos = 0;

  constructor(private tokens: PyToken[]) {}

  private peek(offset = 0): PyToken {
    return this.tokens[Math.min(this.pos + offset, this.tokens.length - 1)];
  }

  private advance(): PyToken {
    const t = this.tokens[this.pos];
    if (this.pos < this.tokens.length - 1) this.pos++;
    return t;
  }

  private check(type: PyTokenType, value?: string): boolean {
    const t = this.peek();
    if (t.type !== type) return false;
    if (value !== undefined && t.value !== value) return false;
    return true;
  }

  private expect(type: PyTokenType, value?: string): PyToken {
    if (!this.check(type, value)) {
      const t = this.peek();
      throw new ParseError(`SyntaxError: expected ${value ?? type} but got '${t.value || t.type}'`, t.line);
    }
    return this.advance();
  }

  private skipNewlines(): void {
    while (this.check("NEWLINE")) this.advance();
  }

  private expectStmtEnd(): void {
    this.expect("NEWLINE");
  }

  parseProgram(): { body: Stmt[]; functions: Map<string, FunctionDefNode>; classNames: Set<string> } {
    const body: Stmt[] = [];
    const functions = new Map<string, FunctionDefNode>();
    const classNames = new Set<string>();
    this.skipNewlines();
    while (!this.check("EOF")) {
      if (this.check("KEYWORD", "def")) {
        const fn = this.parseFunctionDef();
        functions.set(fn.name, fn);
      } else if (this.check("KEYWORD", "class")) {
        const cls = this.parseClass();
        classNames.add(cls.name);
        for (const m of cls.methods) functions.set(m.name, m);
      } else {
        body.push(this.parseStatement());
      }
      this.skipNewlines();
    }
    return { body, functions, classNames };
  }

  private parseClass(): { name: string; methods: FunctionDefNode[] } {
    this.expect("KEYWORD", "class");
    const name = this.expect("NAME").value;
    if (this.check("OP", "(")) {
      while (!this.check("OP", ")")) this.advance();
      this.advance();
    }
    this.expect("OP", ":");
    this.expect("NEWLINE");
    this.expect("INDENT");
    const methods: FunctionDefNode[] = [];
    this.skipNewlines();
    while (!this.check("DEDENT")) {
      if (this.check("KEYWORD", "def")) {
        const fn = this.parseFunctionDef();
        if (fn.params[0] === "self") fn.params = fn.params.slice(1);
        methods.push(fn);
      } else {
        this.parseStatement();
      }
      this.skipNewlines();
    }
    this.expect("DEDENT");
    return { name, methods };
  }

  private parseFunctionDef(): FunctionDefNode {
    const line = this.peek().line;
    this.expect("KEYWORD", "def");
    const name = this.expect("NAME").value;
    this.expect("OP", "(");
    const params: string[] = [];
    while (!this.check("OP", ")")) {
      params.push(this.expect("NAME").value);
      if (this.check("OP", ",")) this.advance();
    }
    this.expect("OP", ")");
    if (this.check("OP", "->")) {
      while (!this.check("OP", ":")) this.advance();
    }
    this.expect("OP", ":");
    const body = this.parseBlock();
    return { type: "FunctionDef", name, params, body, line };
  }

  private parseBlock(): Stmt[] {
    this.expect("NEWLINE");
    this.expect("INDENT");
    const stmts: Stmt[] = [];
    this.skipNewlines();
    while (!this.check("DEDENT")) {
      stmts.push(this.parseStatement());
      this.skipNewlines();
    }
    this.expect("DEDENT");
    return stmts;
  }

  private parseStatement(): Stmt {
    const t = this.peek();
    if (t.type === "KEYWORD") {
      switch (t.value) {
        case "if":
          return this.parseIf();
        case "for":
          return this.parseFor();
        case "while":
          return this.parseWhile();
        case "return":
          return this.parseReturn();
        case "break":
          this.advance();
          this.expectStmtEnd();
          return { type: "Break", line: t.line };
        case "continue":
          this.advance();
          this.expectStmtEnd();
          return { type: "Continue", line: t.line };
        case "pass":
          this.advance();
          this.expectStmtEnd();
          return { type: "Pass", line: t.line };
        case "def":
        case "class":
          throw new ParseError(`SyntaxError: nested '${t.value}' is not supported`, t.line);
      }
    }
    return this.parseSimpleStatement();
  }

  private parseSimpleStatement(): Stmt {
    const line = this.peek().line;
    const first = this.parseTestList();
    if (this.check("OP", "=")) {
      this.advance();
      const value = this.parseTestList();
      this.expectStmtEnd();
      return { type: "Assign", target: first, value, line };
    }
    const t = this.peek();
    if (t.type === "OP" && AUG_OPS.has(t.value)) {
      this.advance();
      const value = this.parseTestList();
      this.expectStmtEnd();
      return { type: "AugAssign", target: first, op: t.value.slice(0, -1), value, line };
    }
    this.expectStmtEnd();
    return { type: "ExprStmt", expr: first, line };
  }

  private parseTestList(): Expr {
    const line = this.peek().line;
    const first = this.parseExpr();
    if (!this.check("OP", ",")) return first;
    const elements = [first];
    while (this.check("OP", ",")) {
      this.advance();
      if (this.check("OP", "=") || this.check("NEWLINE")) break;
      elements.push(this.parseExpr());
    }
    return { type: "TupleExpr", elements, line };
  }

  private parseIf(): Stmt {
    const line = this.peek().line;
    this.expect("KEYWORD", "if");
    const test = this.parseExpr();
    this.expect("OP", ":");
    const body = this.parseBlock();
    const orelse = this.parseElseChain();
    return { type: "If", test, body, orelse, line };
  }

  private parseElseChain(): Stmt[] {
    if (this.check("KEYWORD", "elif")) {
      const line = this.peek().line;
      this.advance();
      const test = this.parseExpr();
      this.expect("OP", ":");
      const body = this.parseBlock();
      const orelse = this.parseElseChain();
      return [{ type: "If", test, body, orelse, line }];
    }
    if (this.check("KEYWORD", "else")) {
      this.advance();
      this.expect("OP", ":");
      return this.parseBlock();
    }
    return [];
  }

  private parseFor(): Stmt {
    const line = this.peek().line;
    this.expect("KEYWORD", "for");
    const target = this.parseTargetList();
    this.expect("KEYWORD", "in");
    const iter = this.parseExpr();
    this.expect("OP", ":");
    const body = this.parseBlock();
    return { type: "For", target, iter, body, line };
  }

  private parseNameTarget(): Expr {
    const t = this.expect("NAME");
    return { type: "Name", id: t.value, line: t.line };
  }

  private parseTargetList(): Expr {
    const line = this.peek().line;
    const first = this.parseNameTarget();
    if (!this.check("OP", ",")) return first;
    const elements = [first];
    while (this.check("OP", ",")) {
      this.advance();
      if (this.check("KEYWORD", "in")) break;
      elements.push(this.parseNameTarget());
    }
    return { type: "TupleExpr", elements, line };
  }

  private parseWhile(): Stmt {
    const line = this.peek().line;
    this.expect("KEYWORD", "while");
    const test = this.parseExpr();
    this.expect("OP", ":");
    const body = this.parseBlock();
    return { type: "While", test, body, line };
  }

  private parseReturn(): Stmt {
    const line = this.peek().line;
    this.expect("KEYWORD", "return");
    let value: Expr | null = null;
    if (!this.check("NEWLINE")) value = this.parseTestList();
    this.expectStmtEnd();
    return { type: "Return", value, line };
  }

  parseExpr(): Expr {
    return this.parseOr();
  }

  private parseOr(): Expr {
    const line = this.peek().line;
    const left = this.parseAnd();
    if (!this.check("KEYWORD", "or")) return left;
    const values = [left];
    while (this.check("KEYWORD", "or")) {
      this.advance();
      values.push(this.parseAnd());
    }
    return { type: "BoolOp", op: "or", values, line };
  }

  private parseAnd(): Expr {
    const line = this.peek().line;
    const left = this.parseNot();
    if (!this.check("KEYWORD", "and")) return left;
    const values = [left];
    while (this.check("KEYWORD", "and")) {
      this.advance();
      values.push(this.parseNot());
    }
    return { type: "BoolOp", op: "and", values, line };
  }

  private parseNot(): Expr {
    if (this.check("KEYWORD", "not")) {
      const t = this.advance();
      return { type: "UnaryOp", op: "not", operand: this.parseNot(), line: t.line };
    }
    return this.parseComparison();
  }

  private isComparisonOp(): boolean {
    const t = this.peek();
    if (t.type === "OP" && COMPARE_OPS.has(t.value)) return true;
    if (t.type === "KEYWORD" && t.value === "in") return true;
    if (t.type === "KEYWORD" && t.value === "not" && this.peek(1).value === "in") return true;
    return false;
  }

  private consumeComparisonOp(): string {
    const t = this.peek();
    if (t.type === "KEYWORD" && t.value === "not") {
      this.advance();
      this.advance();
      return "not in";
    }
    this.advance();
    return t.value;
  }

  private parseComparison(): Expr {
    const line = this.peek().line;
    const left = this.parseAdd();
    const ops: string[] = [];
    const comparators: Expr[] = [];
    while (this.isComparisonOp()) {
      ops.push(this.consumeComparisonOp());
      comparators.push(this.parseAdd());
    }
    if (ops.length === 0) return left;
    return { type: "Compare", left, ops, comparators, line };
  }

  private parseAdd(): Expr {
    let left = this.parseTerm();
    while (this.peek().type === "OP" && (this.peek().value === "+" || this.peek().value === "-")) {
      const t = this.advance();
      const right = this.parseTerm();
      left = { type: "BinOp", op: t.value, left, right, line: t.line };
    }
    return left;
  }

  private parseTerm(): Expr {
    let left = this.parseUnary();
    while (this.peek().type === "OP" && TERM_OPS.has(this.peek().value)) {
      const t = this.advance();
      const right = this.parseUnary();
      left = { type: "BinOp", op: t.value, left, right, line: t.line };
    }
    return left;
  }

  private parseUnary(): Expr {
    if (this.peek().type === "OP" && (this.peek().value === "-" || this.peek().value === "+")) {
      const t = this.advance();
      return { type: "UnaryOp", op: t.value, operand: this.parseUnary(), line: t.line };
    }
    return this.parsePower();
  }

  private parsePower(): Expr {
    const left = this.parsePostfix();
    if (this.check("OP", "**")) {
      const t = this.advance();
      const right = this.parseUnary();
      return { type: "BinOp", op: "**", left, right, line: t.line };
    }
    return left;
  }

  private parsePostfix(): Expr {
    let expr = this.parseAtom();
    for (;;) {
      if (this.check("OP", "(")) {
        const line = this.advance().line;
        const args: Expr[] = [];
        while (!this.check("OP", ")")) {
          args.push(this.parseExpr());
          if (this.check("OP", ",")) this.advance();
        }
        this.expect("OP", ")");
        expr = { type: "Call", callee: expr, args, line };
        continue;
      }
      if (this.check("OP", "[")) {
        const line = this.advance().line;
        const index = this.parseSubscriptIndex(line);
        this.expect("OP", "]");
        expr = { type: "Subscript", obj: expr, index, line };
        continue;
      }
      if (this.check("OP", ".")) {
        const line = this.advance().line;
        const attr = this.expect("NAME").value;
        expr = { type: "Attribute", obj: expr, attr, line };
        continue;
      }
      break;
    }
    return expr;
  }

  private parseSubscriptIndex(line: number): Expr | Slice {
    let lower: Expr | null = null;
    let upper: Expr | null = null;
    let step: Expr | null = null;
    let isSlice = false;
    if (!this.check("OP", ":")) lower = this.parseExpr();
    if (this.check("OP", ":")) {
      isSlice = true;
      this.advance();
      if (!this.check("OP", ":") && !this.check("OP", "]")) upper = this.parseExpr();
      if (this.check("OP", ":")) {
        this.advance();
        if (!this.check("OP", "]")) step = this.parseExpr();
      }
    }
    if (!isSlice) return lower as Expr;
    return { type: "Slice", lower, upper, step, line };
  }

  private parseAtom(): Expr {
    const t = this.peek();
    if (t.type === "NUMBER") {
      this.advance();
      return { type: "Literal", value: t.value.includes(".") ? parseFloat(t.value) : parseInt(t.value, 10), line: t.line };
    }
    if (t.type === "STRING") {
      this.advance();
      return { type: "Literal", value: t.value, line: t.line };
    }
    if (t.type === "FSTRING") {
      this.advance();
      return this.parseFStringBody(t.value, t.line);
    }
    if (t.type === "KEYWORD" && t.value === "True") {
      this.advance();
      return { type: "Literal", value: true, line: t.line };
    }
    if (t.type === "KEYWORD" && t.value === "False") {
      this.advance();
      return { type: "Literal", value: false, line: t.line };
    }
    if (t.type === "KEYWORD" && t.value === "None") {
      this.advance();
      return { type: "Literal", value: null, line: t.line };
    }
    if (t.type === "KEYWORD" && t.value === "self") {
      this.advance();
      return { type: "Name", id: "self", line: t.line };
    }
    if (t.type === "NAME") {
      this.advance();
      return { type: "Name", id: t.value, line: t.line };
    }
    if (t.type === "OP" && t.value === "(") {
      this.advance();
      const inner = this.parseTestList();
      this.expect("OP", ")");
      return inner;
    }
    if (t.type === "OP" && t.value === "[") {
      this.advance();
      const elements: Expr[] = [];
      while (!this.check("OP", "]")) {
        elements.push(this.parseExpr());
        if (this.check("OP", ",")) this.advance();
      }
      this.expect("OP", "]");
      return { type: "ListLiteral", elements, line: t.line };
    }
    throw new ParseError(`SyntaxError: unexpected token '${t.value || t.type}'`, t.line);
  }

  private parseFStringBody(raw: string, line: number): Expr {
    const parts: FStringPart[] = [];
    let i = 0;
    let textBuf = "";
    while (i < raw.length) {
      if (raw[i] === "{" && raw[i + 1] === "{") {
        textBuf += "{";
        i += 2;
        continue;
      }
      if (raw[i] === "}" && raw[i + 1] === "}") {
        textBuf += "}";
        i += 2;
        continue;
      }
      if (raw[i] === "{") {
        if (textBuf) {
          parts.push({ kind: "text", value: unescapeFStringText(textBuf) });
          textBuf = "";
        }
        let depth = 1;
        let j = i + 1;
        while (j < raw.length && depth > 0) {
          if (raw[j] === "{") depth++;
          else if (raw[j] === "}") depth--;
          if (depth > 0) j++;
        }
        const exprSrc = raw.slice(i + 1, j);
        const subParser = new PythonParser(tokenizePython(`${exprSrc}\n`));
        parts.push({ kind: "expr", expr: subParser.parseExpr() });
        i = j + 1;
        continue;
      }
      textBuf += raw[i];
      i++;
    }
    if (textBuf) parts.push({ kind: "text", value: unescapeFStringText(textBuf) });
    return { type: "FString", parts, line };
  }
}

export function parsePython(code: string): ParseResult {
  const tokens = tokenizePython(code);
  const parser = new PythonParser(tokens);
  const { body, functions, classNames } = parser.parseProgram();
  return { program: { body }, functions, classNames };
}
