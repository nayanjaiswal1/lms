// Shared AST every language front-end (languages/python, languages/javascript, …)
// must produce. The interpreter only ever walks these node shapes, so adding a
// new language front-end never touches core/interpreter.ts.

export type Stmt =
  | { type: "FunctionDef"; name: string; params: string[]; body: Stmt[]; line: number }
  | { type: "If"; test: Expr; body: Stmt[]; orelse: Stmt[]; line: number }
  | { type: "For"; target: Expr; iter: Expr; body: Stmt[]; line: number }
  | { type: "While"; test: Expr; body: Stmt[]; line: number }
  | { type: "Assign"; target: Expr; value: Expr; line: number }
  | { type: "AugAssign"; target: Expr; op: string; value: Expr; line: number }
  | { type: "Return"; value: Expr | null; line: number }
  | { type: "Break"; line: number }
  | { type: "Continue"; line: number }
  | { type: "Pass"; line: number }
  | { type: "ExprStmt"; expr: Expr; line: number };

export type Expr =
  | { type: "BinOp"; op: string; left: Expr; right: Expr; line: number }
  | { type: "UnaryOp"; op: string; operand: Expr; line: number }
  | { type: "BoolOp"; op: "and" | "or"; values: Expr[]; line: number }
  | { type: "Compare"; left: Expr; ops: string[]; comparators: Expr[]; line: number }
  | { type: "Call"; callee: Expr; args: Expr[]; line: number }
  | { type: "Subscript"; obj: Expr; index: Expr | Slice; line: number }
  | { type: "Attribute"; obj: Expr; attr: string; line: number }
  | { type: "Name"; id: string; line: number }
  | { type: "Literal"; value: number | string | boolean | null; line: number }
  | { type: "ListLiteral"; elements: Expr[]; line: number }
  | { type: "TupleExpr"; elements: Expr[]; line: number }
  | { type: "FString"; parts: FStringPart[]; line: number };

export interface Slice {
  type: "Slice";
  lower: Expr | null;
  upper: Expr | null;
  step: Expr | null;
  line: number;
}

export type FStringPart = { kind: "text"; value: string } | { kind: "expr"; expr: Expr };

export interface Program {
  body: Stmt[];
}
