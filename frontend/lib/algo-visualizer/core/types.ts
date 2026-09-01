import type { Program, Stmt } from "./ast";

export type FunctionDefNode = Extract<Stmt, { type: "FunctionDef" }>;

export interface Step {
  line: number;
  func: string;
  locals: Record<string, unknown>;
  // Number of stdout lines emitted so far, as of this step — lets the UI
  // reveal output progressively instead of dumping it all at once.
  outputLen: number;
}

export interface TraceResult {
  steps: Step[];
  output: string;
  outputLines: string[];
  error: string | null;
}

export type LanguageId = "python" | "javascript";

export type PyInstance = { __instance_of__: string };
export type PyValue = number | string | boolean | null | PyValue[] | PyInstance;

export interface ParseResult {
  program: Program;
  functions: Map<string, FunctionDefNode>;
  classNames: Set<string>;
}

export interface LanguageFrontend {
  id: LanguageId;
  label: string;
  monacoLanguage: string;
  // Python's `%` floors toward -infinity; JS's `%` truncates toward zero.
  floorMod: boolean;
  parse(code: string): ParseResult;
}

export class ParseError extends Error {
  constructor(
    message: string,
    public line: number,
  ) {
    super(message);
  }
}
