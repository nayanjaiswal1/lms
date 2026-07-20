// VS Code-style user preferences for the lab IDE (editor + terminal),
// persisted in localStorage. A plain module-level store (not React state) so
// the imperative xterm hook can read/subscribe to it the same way React
// components do via useEditorSettings.

export interface EditorSettings {
  /** Applied to both Monaco and the terminal, like VS Code's editor.fontSize default flowing into terminal. */
  fontSize: number
  tabSize: number
  wordWrap: boolean
  minimap: boolean
}

export const EDITOR_SETTINGS_DEFAULTS: EditorSettings = {
  fontSize: 14,
  tabSize: 4,
  wordWrap: true,
  minimap: false,
}

export const EDITOR_FONT_SIZES = [12, 13, 14, 16, 18] as const
export const EDITOR_TAB_SIZES = [2, 4, 8] as const

const STORAGE_KEY = "mindforge:editor-settings"

function load(): EditorSettings {
  if (typeof window === "undefined") return EDITOR_SETTINGS_DEFAULTS
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY)
    if (!raw) return EDITOR_SETTINGS_DEFAULTS
    return { ...EDITOR_SETTINGS_DEFAULTS, ...(JSON.parse(raw) as Partial<EditorSettings>) }
  } catch {
    return EDITOR_SETTINGS_DEFAULTS
  }
}

let current: EditorSettings = load()
const listeners = new Set<() => void>()

export function getEditorSettings(): EditorSettings {
  return current
}

export function updateEditorSettings(patch: Partial<EditorSettings>): void {
  current = { ...current, ...patch }
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(current))
  } catch {
    // Storage full/blocked — settings still apply for this session.
  }
  for (const listener of listeners) listener()
}

export function subscribeEditorSettings(listener: () => void): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}
