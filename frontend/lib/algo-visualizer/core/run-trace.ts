import { runProgram } from "./interpreter";
import type { LanguageFrontend, TraceResult } from "./types";
import { ParseError } from "./types";

export function runTraceWithFrontend(code: string, frontend: LanguageFrontend): TraceResult {
  try {
    const parsed = frontend.parse(code);
    return runProgram(parsed.program, parsed.functions, parsed.classNames, frontend.floorMod);
  } catch (e) {
    if (e instanceof ParseError) {
      return { steps: [], output: "", outputLines: [], error: e.line >= 0 ? `${e.message} (line ${e.line})` : e.message };
    }
    return { steps: [], output: "", outputLines: [], error: e instanceof Error ? e.message : String(e) };
  }
}
