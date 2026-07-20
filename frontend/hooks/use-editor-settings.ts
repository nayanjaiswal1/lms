"use client"

import { useSyncExternalStore } from "react"
import {
  EDITOR_SETTINGS_DEFAULTS,
  getEditorSettings,
  subscribeEditorSettings,
  updateEditorSettings,
} from "@/lib/labs/editor-settings"
import type { EditorSettings } from "@/lib/labs/editor-settings"

/** Live view of the persisted lab IDE settings; every consumer re-renders on change. */
export function useEditorSettings(): {
  settings: EditorSettings
  update: (patch: Partial<EditorSettings>) => void
} {
  const settings = useSyncExternalStore(
    subscribeEditorSettings,
    getEditorSettings,
    () => EDITOR_SETTINGS_DEFAULTS,
  )
  return { settings, update: updateEditorSettings }
}
