"use client"

import { useEffect, useRef } from "react"

// Intercepts a key combo anywhere in the window — no server-component or
// hook-library equivalent exists for a global keydown listener. matches/
// onTrigger are read through refs (matching useLabTimer's onExpiredRef
// pattern) so the listener doesn't get torn down and re-attached on every
// render.
export function useKeyboardShortcut(
  enabled: boolean,
  matches: (e: KeyboardEvent) => boolean,
  onTrigger: () => void,
) {
  const matchesRef = useRef(matches)
  matchesRef.current = matches
  const onTriggerRef = useRef(onTrigger)
  onTriggerRef.current = onTrigger

  useEffect(() => {
    if (!enabled) return

    function onKeyDown(e: KeyboardEvent) {
      if (!matchesRef.current(e)) return
      e.preventDefault()
      onTriggerRef.current()
    }

    window.addEventListener("keydown", onKeyDown)
    return () => window.removeEventListener("keydown", onKeyDown)
  }, [enabled])
}

export const isSaveCombo = (e: KeyboardEvent): boolean =>
  (e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "s"

export const isRunCombo = (e: KeyboardEvent): boolean =>
  (e.ctrlKey || e.metaKey) && e.key === "Enter"
