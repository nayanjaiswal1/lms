import type { Expr, FStringPart, Stmt } from "../../core/ast";
import type { FunctionDefNode, ParseResult } from "../../core/types";
import { ParseError } from "../../core/types";
import { type JsToken, type JsTokenType, tokenizeJavaScript } from "./lexer";

const AUG_OPS = new Set(["+=", "-=", "*=", "/=", "%=", "**="]);
const COMPARE_OPS = new Set(["==", "!=", "===", "!==", "<", "<=", ">", ">="]);
const TERM_OPS = new Set(["*", "/", "%"]);
const MATH_METHODS: Record<string, string> = {
  floor: "floor", ceil: "ceil", round: "round", abs: "abs", max: "max", min: "min", sqrt: "sqrt", pow: "pow",
};

function unescapeTemplateText(s: string): string {
  return s.replace(/\\n/g, "\n").replace(/\\t/g, "\t").replace(/\\\\/g, "\\").replace(/\\`/g, "`");
}

function mapCompareOp(op: string): string {
  if (op === "===") return "==";
  if (op === "!==") return "!=";
  return op;
}

class JavaScriptParser {
  private pos = 0;

  constructor(private tokens: JsToken[]) {}

  private peek(offset = 0): JsToken {
    return this.tokens[Math.min(this.pos + offset, this.tokens.length - 1)];
  }

  private advance(): JsToken {
    const t = this.tokens[this.pos];
    if (this.pos < this.tokens.length - 1) this.pos++;
    return t;
  }

  private check(type: JsTokenType, value?: string): boolean {
    const t = this.peek();
    if (t.type !== type) return false;
    if (value !== undefined && t.value !== value) return false;
    return true;
  }

  private expect(type: JsTokenType, value?: string): JsToken {
    if (!this.check(type, value)) {
      const t = this.peek();
      throw new ParseError(`SyntaxError: expected ${value ?? type} but got '${t.value || t.type}'`, t.line);
    }
    return this.advance();
  }

  private consumeSemi(): void {
    if (this.check("OP", ";")) this.advance();
  }

  parseProgram(): { body: Stmt[]; functions: Map<string, FunctionDefNode>; classNames: Set<string> } {
    const body: Stmt[] = [];
    const functions = new Map<string, FunctionDefNode>();
    const classNames = new Set<string>();
    while (!this.check("EOF")) {
      if (this.check("KEYWORD", "function")) {
        const fn = this.parseFunctionDecl();
        functions.set(fn.name, fn);
        continue;
      }
      if (this.check("KEYWORD", "class")) {
        throw new ParseError("SyntaxError: 'class' is not supported for JavaScript", this.peek().line);
      }
      const maybeFn = this.tryParseFunctionValueDeclaration();
      if (maybeFn) {
        functions.set(maybeFn.name, maybeFn);
        continue;
      }
      for (const s of this.parseStatement()) body.push(s);
    }
    return { body, functions, classNames };
  }

  private parseParamList(): string[] {
    this.expect("OP", "(");
    const params: string[] = [];
    while (!this.check("OP", ")")) {
      params.push(this.expect("NAME").value);
      if (this.check("OP", ",")) this.advance();
    }
    this.expect("OP", ")");
    return params;
  }

  private parseFunctionDecl(): FunctionDefNode {
    const line = this.peek().line;
    this.expect("KEYWORD", "function");
    const name = this.expect("NAME").value;
    const params = this.parseParamList();
    const body = this.parseBraceBlock();
    return { type: "FunctionDef", name, params, body, line };
  }

  private tryParseFunctionValueDeclaration(): FunctionDefNode | null {
    if (!this.check("KEYWORD", "let") && !this.check("KEYWORD", "const") && !this.check("KEYWORD", "var")) return null;
    const start = this.pos;
    const line = this.peek().line;
    this.advance();
    if (!this.check("NAME")) {
      this.pos = start;
      return null;
    }
    const name = this.advance().value;
    if (!this.check("OP", "=")) {
      this.pos = start;
      return null;
    }
    this.advance();
    const fn = this.tryParseFunctionExpression(name, line);
    if (!fn) {
      this.pos = start;
      return null;
    }
    this.consumeSemi();
    return fn;
  }

  private tryParseFunctionExpression(name: string, line: number): FunctionDefNode | null {
    const start = this.pos;
    if (this.check("KEYWORD", "function")) {
      this.advance();
      if (this.check("NAME")) this.advance();
      const params = this.parseParamList();
      const body = this.parseBraceBlock();
      return { type: "FunctionDef", name, params, body, line };
    }
    if (this.check("OP", "(")) {
      const paramsStart = this.pos;
      let params: string[];
      try {
        params = this.parseParamList();
      } catch {
        this.pos = paramsStart;
        return null;
      }
      if (!this.check("OP", "=>")) {
        this.pos = start;
        return null;
      }
      this.advance();
      const body = this.parseArrowBody(line);
      return { type: "FunctionDef", name, params, body, line };
    }
    if (this.check("NAME")) {
      const paramName = this.peek().value;
      const save = this.pos;
      this.advance();
      if (!this.check("OP", "=>")) {
        this.pos = save;
        return null;
      }
      this.advance();
      const body = this.parseArrowBody(line);
      return { type: "FunctionDef", name, params: [paramName], body, line };
    }
    return null;
  }

  private parseArrowBody(line: number): Stmt[] {
    if (this.check("OP", "{")) return this.parseBraceBlock();
    const expr = this.parseExpr();
    this.consumeSemi();
    return [{ type: "Return", value: expr, line }];
  }

  private parseBraceBlock(): Stmt[] {
    this.expect("OP", "{");
    const stmts: Stmt[] = [];
    while (!this.check("OP", "}")) {
      for (const s of this.parseStatement()) stmts.push(s);
    }
    this.expect("OP", "}");
    return stmts;
  }

  private parseControlBody(): Stmt[] {
    return this.parseBraceBlock();
  }

  private parseStatement(): Stmt[] {
    const t = this.peek();
    if (t.type === "KEYWORD") {
      switch (t.value) {
        case "if":
          return [this.parseIf()];
        case "for":
          return this.parseFor();
        case "while":
          return [this.parseWhile()];
        case "return":
          return [this.parseReturn()];
        case "break":
          this.advance();
          this.consumeSemi();
          return [{ type: "Break", line: t.line }];
        case "continue":
          this.advance();
          this.consumeSemi();
          return [{ type: "Continue", line: t.line }];
        case "function":
          throw new ParseError("SyntaxError: nested function declarations are not supported", t.line);
        case "class":
          throw new ParseError("SyntaxError: 'class' is not supported for JavaScript", t.line);
        case "let":
        case "const":
        case "var":
          return [this.parseDeclaration()];
      }
    }
    if (t.type === "OP" && t.value === "[") {
      return [this.parseDestructuringOrArrayExprStatement()];
    }
    return [this.parseExpressionStatement()];
  }

  private parseAssignTargetAtom(): Expr {
    const t = this.expect("NAME");
    return { type: "Name", id: t.value, line: t.line };
  }

  private parseAssignTargetList(): Expr {
    const line = this.peek().line;
    if (this.check("OP", "[")) {
      this.advance();
      const elements: Expr[] = [];
      while (!this.check("OP", "]")) {
        elements.push(this.parseAssignTargetAtom());
        if (this.check("OP", ",")) this.advance();
      }
      this.expect("OP", "]");
      return { type: "TupleExpr", elements, line };
    }
    return this.parseAssignTargetAtom();
  }

  private parseDeclaration(): Stmt {
    const stmt = this.parseDeclarationCore();
    this.consumeSemi();
    return stmt;
  }

  private parseDeclarationCore(): Stmt {
    const line = this.peek().line;
    this.advance();
    const target = this.parseAssignTargetList();
    if (this.check("OP", "=")) {
      this.advance();
      const value = this.parseExpr();
      return { type: "Assign", target, value, line };
    }
    return { type: "Assign", target, value: { type: "Literal", value: null, line }, line };
  }

  private parseDestructureTargetBracket(): Expr {
    const line = this.peek().line;
    this.expect("OP", "[");
    const elements: Expr[] = [];
    while (!this.check("OP", "]")) {
      elements.push(this.parsePostfix());
      if (this.check("OP", ",")) this.advance();
    }
    this.expect("OP", "]");
    return { type: "TupleExpr", elements, line };
  }

  private parseDestructuringOrArrayExprStatement(): Stmt {
    const line = this.peek().line;
    const save = this.pos;
    try {
      const target = this.parseDestructureTargetBracket();
      if (this.check("OP", "=")) {
        this.advance();
        const value = this.parseExpr();
        this.consumeSemi();
        return { type: "Assign", target, value, line };
      }
    } catch {
      // not a destructuring assignment — fall through to a plain expression statement
    }
    this.pos = save;
    return this.parseExpressionStatement();
  }

  private parseExpressionStatement(): Stmt {
    const stmt = this.parseExpressionStatementCore();
    this.consumeSemi();
    return stmt;
  }

  private parseExpressionStatementCore(): Stmt {
    const line = this.peek().line;
    if (this.check("OP", "++") || this.check("OP", "--")) {
      const op = this.advance().value === "++" ? "+" : "-";
      const target = this.parsePostfix();
      return { type: "AugAssign", target, op, value: { type: "Literal", value: 1, line }, line };
    }
    const save = this.pos;
    const target = this.parsePostfix();
    if (this.check("OP", "++") || this.check("OP", "--")) {
      const op = this.advance().value === "++" ? "+" : "-";
      return { type: "AugAssign", target, op, value: { type: "Literal", value: 1, line }, line };
    }
    if (this.check("OP", "=")) {
      this.advance();
      const value = this.parseExpr();
      return { type: "Assign", target, value, line };
    }
    const t = this.peek();
    if (t.type === "OP" && AUG_OPS.has(t.value)) {
      this.advance();
      const value = this.parseExpr();
      return { type: "AugAssign", target, op: t.value.slice(0, -1), value, line };
    }
    this.pos = save;
    const expr = this.parseExpr();
    return { type: "ExprStmt", expr, line };
  }

  private parseIf(): Stmt {
    const line = this.peek().line;
    this.expect("KEYWORD", "if");
    this.expect("OP", "(");
    const test = this.parseExpr();
    this.expect("OP", ")");
    const body = this.parseControlBody();
    let orelse: Stmt[] = [];
    if (this.check("KEYWORD", "else")) {
      this.advance();
      orelse = this.check("KEYWORD", "if") ? [this.parseIf()] : this.parseControlBody();
    }
    return { type: "If", test, body, orelse, line };
  }

  private parseWhile(): Stmt {
    const line = this.peek().line;
    this.expect("KEYWORD", "while");
    this.expect("OP", "(");
    const test = this.parseExpr();
    this.expect("OP", ")");
    const body = this.parseControlBody();
    return { type: "While", test, body, line };
  }

  private parseFor(): Stmt[] {
    const line = this.peek().line;
    this.expect("KEYWORD", "for");
    this.expect("OP", "(");

    if (this.check("KEYWORD", "let") || this.check("KEYWORD", "const") || this.check("KEYWORD", "var")) {
      const save = this.pos;
      this.advance();
      const target = this.parseAssignTargetList();
      if (this.check("KEYWORD", "of")) {
        this.advance();
        const iter = this.parseExpr();
        this.expect("OP", ")");
        const body = this.parseControlBody();
        return [{ type: "For", target, iter, body, line }];
      }
      this.pos = save;
    }

    let init: Stmt | null = null;
    if (!this.check("OP", ";")) {
      init =
        this.check("KEYWORD", "let") || this.check("KEYWORD", "const") || this.check("KEYWORD", "var")
          ? this.parseDeclarationCore()
          : this.parseExpressionStatementCore();
    }
    this.expect("OP", ";");
    let cond: Expr = { type: "Literal", value: true, line };
    if (!this.check("OP", ";")) cond = this.parseExpr();
    this.expect("OP", ";");
    let update: Stmt | null = null;
    if (!this.check("OP", ")")) update = this.parseExpressionStatementCore();
    this.expect("OP", ")");
    const body = this.parseControlBody();
    const whileStmt: Stmt = { type: "While", test: cond, body: update ? [...body, update] : body, line };
    return init ? [init, whileStmt] : [whileStmt];
  }

  private parseReturn(): Stmt {
    const line = this.peek().line;
    this.expect("KEYWORD", "return");
    let value: Expr | null = null;
    if (!this.check("OP", ";") && !this.check("OP", "}")) value = this.parseExpr();
    this.consumeSemi();
    return { type: "Return", value, line };
  }

  parseExpr(): Expr {
    return this.parseOr();
  }

  private parseOr(): Expr {
    const line = this.peek().line;
    const left = this.parseAnd();
    if (!this.check("OP", "||")) return left;
    const values = [left];
    while (this.check("OP", "||")) {
      this.advance();
      values.push(this.parseAnd());
    }
    return { type: "BoolOp", op: "or", values, line };
  }

  private parseAnd(): Expr {
    const line = this.peek().line;
    const left = this.parseComparison();
    if (!this.check("OP", "&&")) return left;
    const values = [left];
    while (this.check("OP", "&&")) {
      this.advance();
      values.push(this.parseComparison());
    }
    return { type: "BoolOp", op: "and", values, line };
  }

  private parseComparison(): Expr {
    const line = this.peek().line;
    const left = this.parseAdd();
    if (!(this.peek().type === "OP" && COMPARE_OPS.has(this.peek().value))) return left;
    const ops: string[] = [];
    const comparators: Expr[] = [];
    while (this.peek().type === "OP" && COMPARE_OPS.has(this.peek().value)) {
      const t = this.advance();
      ops.push(mapCompareOp(t.value));
      comparators.push(this.parseAdd());
    }
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
    const t = this.peek();
    if (t.type === "OP" && (t.value === "-" || t.value === "+" || t.value === "!")) {
      this.advance();
      const op = t.value === "!" ? "not" : t.value;
      return { type: "UnaryOp", op, operand: this.parseUnary(), line: t.line };
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
        const index = this.parseExpr();
        this.expect("OP", "]");
        expr = { type: "Subscript", obj: expr, index, line };
        continue;
      }
      if (this.check("OP", ".")) {
        const line = this.advance().line;
        const attr = this.expect("NAME").value;
        if (expr.type === "Name" && expr.id === "Math") {
          const mapped = MATH_METHODS[attr];
          if (!mapped) throw new ParseError(`SyntaxError: Math.${attr} is not supported`, line);
          expr = { type: "Name", id: mapped, line };
          continue;
        }
        if (expr.type === "Name" && expr.id === "console" && attr === "log") {
          expr = { type: "Name", id: "print", line };
          continue;
        }
        if (attr === "length" && !this.check("OP", "(")) {
          expr = { type: "Call", callee: { type: "Name", id: "len", line }, args: [expr], line };
          continue;
        }
        expr = { type: "Attribute", obj: expr, attr, line };
        continue;
      }
      break;
    }
    return expr;
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
    if (t.type === "TEMPLATE") {
      this.advance();
      return this.parseTemplateBody(t.value, t.line);
    }
    if (t.type === "KEYWORD" && t.value === "true") {
      this.advance();
      return { type: "Literal", value: true, line: t.line };
    }
    if (t.type === "KEYWORD" && t.value === "false") {
      this.advance();
      return { type: "Literal", value: false, line: t.line };
    }
    if (t.type === "KEYWORD" && (t.value === "null" || t.value === "undefined")) {
      this.advance();
      return { type: "Literal", value: null, line: t.line };
    }
    if (t.type === "KEYWORD" && t.value === "this") {
      this.advance();
      return { type: "Name", id: "this", line: t.line };
    }
    if (t.type === "KEYWORD" && t.value === "new") {
      throw new ParseError("SyntaxError: 'new' / class instantiation is not supported for JavaScript", t.line);
    }
    if (t.type === "KEYWORD" && t.value === "function") {
      throw new ParseError(
        "SyntaxError: inline function expressions are only supported as `const name = function(...) {...}`",
        t.line,
      );
    }
    if (t.type === "NAME") {
      this.advance();
      return { type: "Name", id: t.value, line: t.line };
    }
    if (t.type === "OP" && t.value === "(") {
      this.advance();
      const inner = this.parseExpr();
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

  private parseTemplateBody(raw: string, line: number): Expr {
    const parts: FStringPart[] = [];
    let i = 0;
    let textBuf = "";
    while (i < raw.length) {
      if (raw[i] === "$" && raw[i + 1] === "{") {
        if (textBuf) {
          parts.push({ kind: "text", value: unescapeTemplateText(textBuf) });
          textBuf = "";
        }
        let depth = 1;
        let j = i + 2;
        while (j < raw.length && depth > 0) {
          if (raw[j] === "{") depth++;
          else if (raw[j] === "}") depth--;
          if (depth > 0) j++;
        }
        const exprSrc = raw.slice(i + 2, j);
        const subParser = new JavaScriptParser(tokenizeJavaScript(exprSrc));
        parts.push({ kind: "expr", expr: subParser.parseExpr() });
        i = j + 1;
        continue;
      }
      textBuf += raw[i];
      i++;
    }
    if (textBuf) parts.push({ kind: "text", value: unescapeTemplateText(textBuf) });
    return { type: "FString", parts, line };
  }
}

export function parseJavaScript(code: string): ParseResult {
  const tokens = tokenizeJavaScript(code);
  const parser = new JavaScriptParser(tokens);
  const { body, functions, classNames } = parser.parseProgram();
  return { program: { body }, functions, classNames };
}
