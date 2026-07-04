"use client"

import { useEffect, useRef } from "react"

// Intercepts Ctrl+S / Cmd+S while a lab file is open so the browser's native
// "save page" dialog never fires — no server-component or hook-library
// equivalent exists for a global keydown listener. onSave is read through a
// ref (matching useLabTimer's onExpiredRef pattern) so the listener doesn't
// get torn down and re-attached on every render.
export function useLabSaveShortcut(enabled: boolean, onSave: () => void) {
  const onSaveRef = useRef(onSave)
  onSaveRef.current = onSave

  useEffect(() => {
    if (!enabled) return

    function onKeyDown(e: KeyboardEvent) {
      const isSaveCombo = (e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "s"
      if (!isSaveCombo) return
      e.preventDefault()
      onSaveRef.current()
    }

    window.addEventListener("keydown", onKeyDown)
    return () => window.removeEventListener("keydown", onKeyDown)
  }, [enabled])
}
