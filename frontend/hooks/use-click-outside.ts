"use client"

import { useEffect, useRef } from "react"

// Detects a pointerdown outside the returned ref's element — no server-component
// or hook-library equivalent exists for a global click listener. onOutsideClick is
// read through a ref (matching useKeyboardShortcut's pattern) so the listener
// doesn't get torn down and re-attached on every render.
export function useClickOutside<T extends HTMLElement>(onOutsideClick: () => void) {
  const ref = useRef<T>(null)
  const onOutsideClickRef = useRef(onOutsideClick)
  onOutsideClickRef.current = onOutsideClick

  useEffect(() => {
    function onPointerDown(e: PointerEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        onOutsideClickRef.current()
      }
    }
    document.addEventListener("pointerdown", onPointerDown)
    return () => document.removeEventListener("pointerdown", onPointerDown)
  }, [])

  return ref
}
