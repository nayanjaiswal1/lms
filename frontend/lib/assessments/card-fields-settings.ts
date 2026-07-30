// Which metadata fields show on each question card in the assessment builder
// (questions-panel.tsx) — a per-admin display preference, so it persists in
// localStorage rather than the URL or the backend. Same module-level store
// shape as lib/labs/editor-settings.ts / lib/assessments/header-stats-settings.ts.

export type CardFieldKey = "type" | "difficulty" | "points" | "tags" | "prompt";

export const CARD_FIELD_LABELS: Record<CardFieldKey, string> = {
  type: "Type",
  difficulty: "Difficulty",
  points: "Points",
  tags: "Tags",
  prompt: "Prompt preview",
};

export type CardFieldsSettings = Record<CardFieldKey, boolean>;

export const CARD_FIELDS_DEFAULTS: CardFieldsSettings = {
  type: true,
  difficulty: true,
  points: true,
  tags: true,
  prompt: true,
};

const STORAGE_KEY = "mindforge:assessment-card-fields";

function load(): CardFieldsSettings {
  if (typeof window === "undefined") return CARD_FIELDS_DEFAULTS;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return CARD_FIELDS_DEFAULTS;
    return { ...CARD_FIELDS_DEFAULTS, ...(JSON.parse(raw) as Partial<CardFieldsSettings>) };
  } catch {
    return CARD_FIELDS_DEFAULTS;
  }
}

let current: CardFieldsSettings = load();
const listeners = new Set<() => void>();

export function getCardFieldsSettings(): CardFieldsSettings {
  return current;
}

export function toggleCardField(key: CardFieldKey, value: boolean): void {
  current = { ...current, [key]: value };
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(current));
  } catch {
    // Storage full/blocked — setting still applies for this session.
  }
  for (const listener of listeners) listener();
}

export function subscribeCardFieldsSettings(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}
