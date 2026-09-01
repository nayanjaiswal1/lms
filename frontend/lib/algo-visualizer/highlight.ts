import type { LanguageId } from "./core/types";

const KEYWORDS: Record<LanguageId, Set<string>> = {
  python: new Set([
    "def", "return", "if", "elif", "else", "for", "while", "in", "not", "and", "or",
    "True", "False", "None", "break", "continue", "import", "from", "class", "pass",
    "is", "lambda", "yield", "with", "as", "try", "except", "finally", "raise",
    "global", "nonlocal", "del", "assert",
  ]),
  javascript: new Set([
    "function", "return", "if", "else", "for", "while", "in", "of", "true", "false",
    "null", "undefined", "break", "continue", "import", "from", "class", "new",
    "typeof", "instanceof", "let", "const", "var", "try", "catch", "finally", "throw",
    "switch", "case", "default", "this", "async", "await", "yield", "export",
  ]),
};

export type TokenClass = "keyword" | "string" | "comment" | "number" | "call" | "plain";

export interface Token {
  text: string;
  cls: TokenClass;
}

const TOKEN_PATTERN =
  /("(?:[^"\\]|\\.)*"?|'(?:[^'\\]|\\.)*'?|`(?:[^`\\]|\\.)*`?|\/\/.*|#.*|\b\d+\.?\d*\b|[A-Za-z_]\w*)/g;

// Regex-based tokenizer, not a real parser — good enough for the two toy
// languages this visualizer supports, avoids pulling in a highlighting
// library for two keyword sets.
export function tokenizeLine(line: string, language: LanguageId): Token[] {
  const keywords = KEYWORDS[language];
  const tokens: Token[] = [];
  const re = new RegExp(TOKEN_PATTERN);
  let lastEnd = 0;
  let match: RegExpExecArray | null;

  while ((match = re.exec(line))) {
    if (match.index > lastEnd) tokens.push({ text: line.slice(lastEnd, match.index), cls: "plain" });
    const text = match[0];
    let cls: TokenClass = "plain";
    if (text.startsWith('"') || text.startsWith("'") || text.startsWith("`")) cls = "string";
    else if (text.startsWith("//") || text.startsWith("#")) cls = "comment";
    else if (/^\d/.test(text)) cls = "number";
    else if (keywords.has(text)) cls = "keyword";
    else if (/^[A-Za-z_]\w*$/.test(text) && line[re.lastIndex] === "(") cls = "call";
    tokens.push({ text, cls });
    lastEnd = re.lastIndex;
  }
  if (lastEnd < line.length) tokens.push({ text: line.slice(lastEnd), cls: "plain" });
  return tokens;
}
