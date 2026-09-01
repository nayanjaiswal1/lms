import type { Step } from "./types";

export const DEFAULT_POINTER_NAMES = [
  "i", "j", "k", "left", "right", "low", "high", "mid", "lo", "hi",
  "idx", "index", "pos", "start", "end",
];

// Stable across the 8 habit-color tokens already defined in globals.css —
// reused here instead of inventing new pointer-only colors.
export const POINTER_COLORS = [
  "habit-blue", "habit-orange", "habit-aqua", "habit-yellow",
  "habit-magenta", "habit-green", "habit-violet", "habit-red",
] as const;

export interface PointerInfo {
  name: string;
  arrayName: string;
  index: number;
  color: (typeof POINTER_COLORS)[number];
}

export type PrimitiveArrayValue = number | string | boolean;

function isPrimitiveArray(v: unknown): v is PrimitiveArrayValue[] {
  return (
    Array.isArray(v) && v.every((x) => typeof x === "number" || typeof x === "string" || typeof x === "boolean")
  );
}

export function detectPointers(
  locals: Record<string, unknown>,
  pointerNames: readonly string[],
  colorMap: Map<string, (typeof POINTER_COLORS)[number]>,
): PointerInfo[] {
  const arrays = Object.entries(locals).filter(([, v]) => isPrimitiveArray(v)) as [string, PrimitiveArrayValue[]][];
  if (arrays.length === 0) return [];

  const out: PointerInfo[] = [];
  for (const [name, value] of Object.entries(locals)) {
    if (typeof value !== "number" || !Number.isInteger(value)) continue;
    if (!pointerNames.includes(name)) continue;
    const arr = arrays.find(([, a]) => value >= 0 && value < a.length);
    if (!arr) continue;
    let color = colorMap.get(name);
    if (!color) {
      color = POINTER_COLORS[colorMap.size % POINTER_COLORS.length];
      colorMap.set(name, color);
    }
    out.push({ name, arrayName: arr[0], index: value, color });
  }
  return out;
}

export function arrayLocals(locals: Record<string, unknown>): [string, PrimitiveArrayValue[]][] {
  return Object.entries(locals).filter(([, v]) => isPrimitiveArray(v)) as [string, PrimitiveArrayValue[]][];
}

export function stepsTouchArray(steps: Step[]): boolean {
  return steps.some((s) => arrayLocals(s.locals).length > 0);
}
