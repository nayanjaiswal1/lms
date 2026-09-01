import { runTraceWithFrontend } from "../core/run-trace";
import type { LanguageFrontend, LanguageId, TraceResult } from "../core/types";
import { parseJavaScript } from "./javascript/parser";
import { parsePython } from "./python/parser";

export const LANGUAGES: Record<LanguageId, LanguageFrontend> = {
  python: {
    id: "python",
    label: "Python",
    monacoLanguage: "python",
    floorMod: true,
    parse: parsePython,
  },
  javascript: {
    id: "javascript",
    label: "JavaScript",
    monacoLanguage: "javascript",
    floorMod: false,
    parse: parseJavaScript,
  },
};

export const LANGUAGE_LIST: LanguageFrontend[] = Object.values(LANGUAGES);

export function runTrace(code: string, language: LanguageId): TraceResult {
  return runTraceWithFrontend(code, LANGUAGES[language]);
}
