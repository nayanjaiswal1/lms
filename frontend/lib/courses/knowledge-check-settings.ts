import { useSyncExternalStore } from "react"

// Learner preference: hide every lesson's Knowledge Check across all courses.
// Per-device display preference, so it lives in localStorage (same module-level
// store shape as lib/labs/editor-settings.ts). The server's completion gate is
// lifted for it via updateProgressAction's skip_checks.

const STORAGE_KEY = "mindforge:hide-knowledge-checks"

function load(): boolean {
  if (typeof window === "undefined") return false
  try {
    return window.localStorage.getItem(STORAGE_KEY) === "true"
  } catch {
    return false
  }
}

let current = load()
const listeners = new Set<() => void>()

export function setHideKnowledgeChecks(value: boolean): void {
  current = value
  try {
    window.localStorage.setItem(STORAGE_KEY, String(value))
  } catch {
    // Storage full/blocked — setting still applies for this session.
  }
  for (const listener of listeners) listener()
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

export function useHideKnowledgeChecks(): boolean {
  return useSyncExternalStore(subscribe, () => current, () => false)
}
