// Heuristic-only, no LLM call — keeps quick-mode creation at the same cost it
// always had (one question-generation call, nothing else). Short, single-line
// input with no JD-shaped language reads as "just a topic" (quick); anything
// longer or role/JD-shaped goes through the full extraction flow (targeted).
const JD_SIGNAL_PATTERN =
  /\byears?\b|\bresponsibilit(y|ies)\b|\brequirements?\b|\bqualifications?\b|\bexperience\b|\bdegree\b/i;
const QUICK_INPUT_MAX_CHARS = 60;

export type PrepMode = "quick" | "targeted";

export function classifyPrepInput(text: string): PrepMode {
  const trimmed = text.trim();
  if (trimmed.length > QUICK_INPUT_MAX_CHARS || trimmed.includes("\n") || JD_SIGNAL_PATTERN.test(trimmed)) {
    return "targeted";
  }
  return "quick";
}
