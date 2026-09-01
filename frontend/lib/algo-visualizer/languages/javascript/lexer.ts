export type JsTokenType = "NUMBER" | "STRING" | "TEMPLATE" | "NAME" | "KEYWORD" | "OP" | "EOF";

export interface JsToken {
  type: JsTokenType;
  value: string;
  line: number;
}

const KEYWORDS = new Set([
  "function", "if", "else", "for", "while", "return", "break", "continue",
  "let", "const", "var", "true", "false", "null", "undefined", "of", "in", "new", "class", "this",
]);

const OPERATORS = [
  "===", "!==", "=>", "**=",
  "&&", "||", "==", "!=", "<=", ">=", "++", "--", "+=", "-=", "*=", "/=", "%=", "**",
  "(", ")", "{", "}", "[", "]", ";", ",", ".", ":", "+", "-", "*", "/", "%", "<", ">", "=", "!",
];

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

export function tokenizeJavaScript(source: string): JsToken[] {
  const tokens: JsToken[] = [];
  let i = 0;
  let line = 1;
  const n = source.length;

  while (i < n) {
    const c = source[i];
    if (c === "\n") {
      line++;
      i++;
      continue;
    }
    if (c === " " || c === "\t" || c === "\r") {
      i++;
      continue;
    }
    if (c === "/" && source[i + 1] === "/") {
      while (i < n && source[i] !== "\n") i++;
      continue;
    }
    if (c === "/" && source[i + 1] === "*") {
      i += 2;
      while (i < n && !(source[i] === "*" && source[i + 1] === "/")) {
        if (source[i] === "\n") line++;
        i++;
      }
      i += 2;
      continue;
    }
    if (c === '"' || c === "'") {
      const quote = c;
      let j = i + 1;
      let raw = "";
      while (j < n && source[j] !== quote) {
        if (source[j] === "\\") {
          raw += unescapeChar(source[j + 1]);
          j += 2;
          continue;
        }
        raw += source[j];
        j++;
      }
      tokens.push({ type: "STRING", value: raw, line });
      i = j + 1;
      continue;
    }
    if (c === "`") {
      let j = i + 1;
      let raw = "";
      while (j < n && source[j] !== "`") {
        if (source[j] === "\\") {
          raw += source[j] + (source[j + 1] ?? "");
          j += 2;
          continue;
        }
        if (source[j] === "\n") line++;
        raw += source[j];
        j++;
      }
      tokens.push({ type: "TEMPLATE", value: raw, line });
      i = j + 1;
      continue;
    }
    if (/[0-9]/.test(c)) {
      let j = i;
      while (j < n && /[0-9.]/.test(source[j])) j++;
      tokens.push({ type: "NUMBER", value: source.slice(i, j), line });
      i = j;
      continue;
    }
    if (/[A-Za-z_$]/.test(c)) {
      let j = i;
      while (j < n && /[A-Za-z0-9_$]/.test(source[j])) j++;
      const word = source.slice(i, j);
      tokens.push({ type: KEYWORDS.has(word) ? "KEYWORD" : "NAME", value: word, line });
      i = j;
      continue;
    }
    let matched = false;
    for (const op of OPERATORS) {
      if (source.startsWith(op, i)) {
        tokens.push({ type: "OP", value: op, line });
        i += op.length;
        matched = true;
        break;
      }
    }
    if (!matched) i++;
  }

  tokens.push({ type: "EOF", value: "", line });
  return tokens;
}
