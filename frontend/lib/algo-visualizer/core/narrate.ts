import { arrayLocals, type PrimitiveArrayValue } from "./pointer-detect";
import type { PyValue, Step } from "./types";
import { pyStr } from "./values";

export type StructureKind = "array" | "stack" | "queue";

export interface StepNarration {
  phase: string;
  caption: string;
}

function arraysEqual(a: PrimitiveArrayValue[], b: PrimitiveArrayValue[]): boolean {
  return a.length === b.length && a.every((v, i) => v === b[i]);
}

// Classifies a variable's whole trace history: one that only ever grows or
// shrinks at its tail is a stack; one that also touches its head (unshift or
// front-removal) is a queue; anything else — in-place mutation, arbitrary
// insert/remove — is a plain array (sorting/searching's bar-chart view).
export function classifyStructure(steps: Step[], name: string): StructureKind {
  let sawTail = false;
  let sawHead = false;
  let prev: PrimitiveArrayValue[] | undefined;

  for (const step of steps) {
    const curr = arrayLocals(step.locals).find(([n]) => n === name)?.[1];
    if (curr === undefined) {
      prev = undefined;
      continue;
    }
    if (prev !== undefined) {
      if (curr.length > prev.length) {
        if (arraysEqual(curr.slice(0, prev.length), prev)) sawTail = true;
        else if (arraysEqual(curr.slice(curr.length - prev.length), prev)) sawHead = true;
        else return "array";
      } else if (curr.length < prev.length) {
        if (arraysEqual(prev.slice(0, curr.length), curr)) sawTail = true;
        else if (arraysEqual(prev.slice(prev.length - curr.length), curr)) sawHead = true;
        else return "array";
      } else if (!arraysEqual(curr, prev)) {
        return "array";
      }
    }
    prev = curr;
  }

  if (sawHead) return "queue";
  if (sawTail) return "stack";
  return "array";
}

function fmt(v: unknown): string {
  return typeof v === "string" ? `'${v}'` : pyStr(v as PyValue);
}

function describeArrayChange(name: string, prev: PrimitiveArrayValue[], curr: PrimitiveArrayValue[]): StepNarration | null {
  if (arraysEqual(prev, curr)) return null;
  const delta = curr.length - prev.length;

  if (delta === 1) {
    if (arraysEqual(curr.slice(0, prev.length), prev)) {
      return { phase: "Push", caption: `push(${fmt(curr[curr.length - 1])}) → ${name} size ${curr.length}` };
    }
    if (arraysEqual(curr.slice(1), prev)) {
      return { phase: "Enqueue", caption: `enqueue(${fmt(curr[0])}) → ${name} size ${curr.length}` };
    }
    return { phase: "Insert", caption: `${name} grew to size ${curr.length}` };
  }
  if (delta === -1) {
    if (arraysEqual(prev.slice(0, curr.length), curr)) {
      return { phase: "Pop", caption: `pop() → ${fmt(prev[prev.length - 1])} removed, ${name} size ${curr.length}` };
    }
    if (arraysEqual(prev.slice(1), curr)) {
      return { phase: "Dequeue", caption: `dequeue() → ${fmt(prev[0])} removed, ${name} size ${curr.length}` };
    }
    return { phase: "Remove", caption: `${name} shrank to size ${curr.length}` };
  }
  if (delta === 0) {
    const diffs: number[] = [];
    for (let i = 0; i < curr.length; i++) if (curr[i] !== prev[i]) diffs.push(i);
    if (diffs.length === 2 && prev[diffs[0]] === curr[diffs[1]] && prev[diffs[1]] === curr[diffs[0]]) {
      return { phase: "Swap", caption: `${name}[${diffs[0]}] ↔ ${name}[${diffs[1]}] swapped` };
    }
    if (diffs.length > 0) {
      return { phase: "Assign", caption: `${name}[${diffs[0]}] = ${fmt(curr[diffs[0]])}` };
    }
  }
  return null;
}

function keywordPhase(line: string): StepNarration {
  const trimmed = line.trim();
  if (trimmed.startsWith("return")) return { phase: "Return", caption: trimmed };
  if (/^(for|while)\b/.test(trimmed)) return { phase: "Loop", caption: trimmed };
  if (/^(if|elif|else)\b/.test(trimmed)) return { phase: "Compare", caption: trimmed };
  if (/^(def|function)\b/.test(trimmed)) return { phase: "Call", caption: trimmed };
  return { phase: "Step", caption: trimmed || "…" };
}

// Best-effort plain-English caption for a step, derived purely from the
// locals diff (no changes to the trace schema) — falls back to the source
// line itself when nothing structural changed on this step.
export function narrateStep(
  prevLocals: Record<string, unknown> | undefined,
  curr: Step,
  sourceLine: string,
): StepNarration {
  if (prevLocals) {
    const prevArrays = new Map(arrayLocals(prevLocals));
    for (const [name, value] of arrayLocals(curr.locals)) {
      const prevValue = prevArrays.get(name);
      if (!prevValue) continue;
      const event = describeArrayChange(name, prevValue, value);
      if (event) return event;
    }
    for (const [key, value] of Object.entries(curr.locals)) {
      if (Array.isArray(value)) continue;
      if (!(key in prevLocals) || prevLocals[key] !== value) {
        return { phase: "Assign", caption: `${key} = ${fmt(value)}` };
      }
    }
  }
  return keywordPhase(sourceLine);
}
