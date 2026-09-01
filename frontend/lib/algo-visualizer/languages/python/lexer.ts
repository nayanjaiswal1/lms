export type PyTokenType = "NEWLINE" | "INDENT" | "DEDENT" | "EOF" | "NAME" | "NUMBER" | "STRING" | "FSTRING" | "OP" | "KEYWORD";

export interface PyToken {
  type: PyTokenType;
  value: string;
  line: number;
}

const KEYWORDS = new Set([
  "def", "if", "elif", "else", "for", "while", "return", "break", "continue", "pass",
  "and", "or", "not", "in", "True", "False", "None", "class", "self",
]);

const OPERATORS = [
  "**=", "//=", "==", "!=", "<=", ">=", "//", "**", "+=", "-=", "*=", "/=", "%=", "->",
  "(", ")", "[", "]", "{", "}", ":", ",", ".", "+", "-", "*", "/", "%", "<", ">", "=",
];

function stripComment(line: string): string {
  let inStr: string | null = null;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (inStr) {
      if (c === "\\") {
        i++;
        continue;
      }
      if (c === inStr) inStr = null;
      continue;
    }
    if (c === '"' || c === "'") {
      inStr = c;
      continue;
    }
    if (c === "#") return line.slice(0, i);
  }
  return line;
}

function unescapeChar(c: string): string {
  switch (c) {
    case "n":
      return "\n";
    case "t":
      return "\t";
    case "\\":
      return "\\";
    case "'":
      return "'";
    case '"':
      return '"';
    default:
      return c;
  }
}

function tokenizeLineContent(content: string, line: number, tokens: PyToken[]): void {
  let i = 0;
  const n = content.length;
  while (i < n) {
    const c = content[i];
    if (c === " ") {
      i++;
      continue;
    }
    if (c === "f" && (content[i + 1] === '"' || content[i + 1] === "'")) {
      const quote = content[i + 1];
      let j = i + 2;
      let raw = "";
      while (j < n && content[j] !== quote) {
        if (content[j] === "\\") {
          raw += content[j] + (content[j + 1] ?? "");
          j += 2;
          continue;
        }
        raw += content[j];
        j++;
      }
      tokens.push({ type: "FSTRING", value: raw, line });
      i = j + 1;
      continue;
    }
    if (c === '"' || c === "'") {
      let j = i + 1;
      let raw = "";
      while (j < n && content[j] !== c) {
        if (content[j] === "\\") {
          raw += unescapeChar(content[j + 1]);
          j += 2;
          continue;
        }
        raw += content[j];
        j++;
      }
      tokens.push({ type: "STRING", value: raw, line });
      i = j + 1;
      continue;
    }
    if (/[0-9]/.test(c)) {
      let j = i;
      while (j < n && /[0-9.]/.test(content[j])) j++;
      tokens.push({ type: "NUMBER", value: content.slice(i, j), line });
      i = j;
      continue;
    }
    if (/[A-Za-z_]/.test(c)) {
      let j = i;
      while (j < n && /[A-Za-z0-9_]/.test(content[j])) j++;
      const word = content.slice(i, j);
      tokens.push({ type: KEYWORDS.has(word) ? "KEYWORD" : "NAME", value: word, line });
      i = j;
      continue;
    }
    let matched = false;
    for (const op of OPERATORS) {
      if (content.startsWith(op, i)) {
        tokens.push({ type: "OP", value: op, line });
        i += op.length;
        matched = true;
        break;
      }
    }
    if (!matched) i++;
  }
}

export function tokenizePython(source: string): PyToken[] {
  const lines = source.replace(/\t/g, "    ").split("\n");
  const tokens: PyToken[] = [];
  const indentStack = [0];
  let lineNo = 0;

  for (const rawLine of lines) {
    lineNo++;
    const stripped = stripComment(rawLine);
    if (stripped.trim() === "") continue;

    const indentWidth = stripped.length - stripped.trimStart().length;
    const content = stripped.slice(indentWidth);

    if (indentWidth > indentStack[indentStack.length - 1]) {
      indentStack.push(indentWidth);
      tokens.push({ type: "INDENT", value: "", line: lineNo });
    } else {
      while (indentWidth < indentStack[indentStack.length - 1]) {
        indentStack.pop();
        tokens.push({ type: "DEDENT", value: "", line: lineNo });
      }
    }

    tokenizeLineContent(content, lineNo, tokens);
    tokens.push({ type: "NEWLINE", value: "", line: lineNo });
  }

  while (indentStack.length > 1) {
    indentStack.pop();
    tokens.push({ type: "DEDENT", value: "", line: lineNo });
  }
  tokens.push({ type: "EOF", value: "", line: lineNo });
  return tokens;
}
