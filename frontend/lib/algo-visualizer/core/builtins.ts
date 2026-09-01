import type { PyValue } from "./types";
import { RuntimeErrorSignal, describeType, normalizeIndex, num, pyEquals, pySlice, pyStr, truthy } from "./values";

const MAX_RANGE = 100000;

function asArray(v: PyValue, line: number): PyValue[] {
  if (Array.isArray(v)) return v;
  if (typeof v === "string") return v.split("");
  throw new RuntimeErrorSignal(`TypeError: '${describeType(v)}' object is not iterable`, line);
}

function defaultCompare(a: PyValue, b: PyValue): number {
  if (typeof a === "string" && typeof b === "string") return a < b ? -1 : a > b ? 1 : 0;
  return (a as number) - (b as number);
}

function rangeOf(args: PyValue[], line: number): number[] {
  let start = 0;
  let stop: number;
  let step = 1;
  if (args.length === 1) {
    stop = num(args[0], line);
  } else if (args.length >= 2) {
    start = num(args[0], line);
    stop = num(args[1], line);
    if (args.length >= 3) step = num(args[2], line);
  } else {
    throw new RuntimeErrorSignal("TypeError: range expected at least 1 argument, got 0", line);
  }
  if (step === 0) throw new RuntimeErrorSignal("ValueError: range() arg 3 must not be zero", line);
  const out: number[] = [];
  if (step > 0) {
    for (let i = start; i < stop && out.length <= MAX_RANGE; i += step) out.push(i);
  } else {
    for (let i = start; i > stop && out.length <= MAX_RANGE; i += step) out.push(i);
  }
  if (out.length > MAX_RANGE) {
    throw new RuntimeErrorSignal("range() would produce too many values — reduce the bound", line);
  }
  return out;
}

export function callBuiltin(name: string, args: PyValue[], output: string[], line: number): PyValue {
  switch (name) {
    case "print":
      output.push(args.map(pyStr).join(" "));
      return null;
    case "len":
      return asArray(args[0], line).length;
    case "range":
      return rangeOf(args, line);
    case "min":
      return (args.length === 1 ? asArray(args[0], line) : args).reduce((a, b) =>
        compareLess(b, a) ? b : a,
      );
    case "max":
      return (args.length === 1 ? asArray(args[0], line) : args).reduce((a, b) =>
        compareLess(a, b) ? b : a,
      );
    case "sum": {
      const start = typeof args[1] === "number" ? args[1] : 0;
      return asArray(args[0], line).reduce((a: number, b) => a + num(b, line), start);
    }
    case "abs":
      return Math.abs(num(args[0], line));
    case "floor":
      return Math.floor(num(args[0], line));
    case "ceil":
      return Math.ceil(num(args[0], line));
    case "sqrt":
      return Math.sqrt(num(args[0], line));
    case "pow":
      return Math.pow(num(args[0], line), num(args[1], line));
    case "round": {
      const n = num(args[0], line);
      if (args.length > 1) {
        const digits = num(args[1], line);
        const f = Math.pow(10, digits);
        return Math.round(n * f) / f;
      }
      return Math.round(n);
    }
    case "sorted": {
      const arr = [...asArray(args[0], line)];
      arr.sort(defaultCompare);
      return arr;
    }
    case "list":
      return args[0] === undefined ? [] : [...asArray(args[0], line)];
    case "int":
      return Math.trunc(typeof args[0] === "string" ? parseFloat(args[0]) : num(args[0], line));
    case "float":
      return typeof args[0] === "string" ? parseFloat(args[0]) : num(args[0], line);
    case "str":
      return pyStr(args[0]);
    case "bool":
      return truthy(args[0]);
    case "enumerate": {
      const arr = asArray(args[0], line);
      const start = typeof args[1] === "number" ? args[1] : 0;
      return arr.map((v, i) => [i + start, v]);
    }
    case "zip": {
      const arrs = args.map((a) => asArray(a, line));
      const n = Math.min(...arrs.map((a) => a.length));
      const out: PyValue[] = [];
      for (let i = 0; i < n; i++) out.push(arrs.map((a) => a[i]));
      return out;
    }
    case "reversed":
      return [...asArray(args[0], line)].reverse();
    default:
      throw new RuntimeErrorSignal(`NameError: name '${name}' is not defined`, line);
  }
}

function compareLess(a: PyValue, b: PyValue): boolean {
  return defaultCompare(a, b) < 0;
}

export function callListMethod(arr: PyValue[], method: string, args: PyValue[], line: number): PyValue {
  switch (method) {
    case "append":
    case "push":
      arr.push(args[0]);
      return arr.length;
    case "pop": {
      if (arr.length === 0) throw new RuntimeErrorSignal("IndexError: pop from empty list", line);
      const i = args.length ? normalizeIndex(arr.length, num(args[0], line), line) : arr.length - 1;
      return arr.splice(i, 1)[0];
    }
    case "insert": {
      const raw = num(args[0], line);
      const i = Math.max(0, Math.min(arr.length, raw < 0 ? raw + arr.length : raw));
      arr.splice(i, 0, args[1]);
      return null;
    }
    case "remove": {
      const i = arr.findIndex((v) => pyEquals(v, args[0]));
      if (i === -1) throw new RuntimeErrorSignal("ValueError: value not in list", line);
      arr.splice(i, 1);
      return null;
    }
    case "reverse":
      arr.reverse();
      return null;
    case "sort":
      arr.sort(defaultCompare);
      return null;
    case "index": {
      const i = arr.findIndex((v) => pyEquals(v, args[0]));
      if (i === -1) throw new RuntimeErrorSignal("ValueError: value not in list", line);
      return i;
    }
    case "count":
      return arr.filter((v) => pyEquals(v, args[0])).length;
    case "copy":
      return [...arr];
    case "clear":
      arr.length = 0;
      return null;
    case "slice":
      return pySlice(arr, args[0] === undefined ? 0 : num(args[0], line), args[1] === undefined ? arr.length : num(args[1], line), 1);
    case "at":
      return arr[normalizeIndex(arr.length, num(args[0], line), line)];
    case "shift": {
      if (arr.length === 0) throw new RuntimeErrorSignal("TypeError: shift from empty array", line);
      return arr.shift() as PyValue;
    }
    case "unshift":
      arr.unshift(args[0]);
      return arr.length;
    default:
      throw new RuntimeErrorSignal(`AttributeError: 'list' object has no attribute '${method}'`, line);
  }
}

export function callStringMethod(s: string, method: string, args: PyValue[], line: number): PyValue {
  switch (method) {
    case "upper":
      return s.toUpperCase();
    case "lower":
      return s.toLowerCase();
    case "strip":
    case "trim":
      return s.trim();
    case "split":
      return args.length ? s.split(String(args[0])) : s.split(/\s+/).filter(Boolean);
    case "join":
      return asArray(args[0], line).map(pyStr).join(s);
    case "replace":
      return s.split(String(args[0])).join(String(args[1]));
    case "startswith":
    case "startsWith":
      return s.startsWith(String(args[0]));
    case "endswith":
    case "endsWith":
      return s.endsWith(String(args[0]));
    case "find":
    case "indexOf":
      return s.indexOf(String(args[0]));
    case "slice":
    case "substring":
      return pySlice(s, args[0] === undefined ? 0 : num(args[0], line), args[1] === undefined ? s.length : num(args[1], line), 1);
    case "at":
      return s[normalizeIndex(s.length, num(args[0], line), line)];
    default:
      throw new RuntimeErrorSignal(`AttributeError: 'str' object has no attribute '${method}'`, line);
  }
}
