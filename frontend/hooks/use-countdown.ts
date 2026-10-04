"use client"

import { useSyncExternalStore } from "react"

function subscribe(listener: () => void): () => void {
  const id = setInterval(listener, 1000)
  return () => clearInterval(id)
}

/** Whole seconds left until `untilMs` (epoch ms); 0 when elapsed or unset. Re-renders once a second. */
export function useCountdown(untilMs: number): number {
  return useSyncExternalStore(
    subscribe,
    () => (untilMs > 0 ? Math.max(0, Math.ceil((untilMs - Date.now()) / 1000)) : 0),
    () => 0,
  )
}
