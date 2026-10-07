"use client"

import { useEffect, useState } from "react"

/** First wait for the IDE's load event; doubles on every automatic retry. */
const IDE_LOAD_TIMEOUT_MS = 12_000
/** Silent reloads before the student is asked to reload by hand. */
const IDE_MAX_AUTO_RETRIES = 3

interface FrameLoadState {
  isLoaded: boolean
  /** Bumped on every reload; used as the iframe key and to pick a fresh-token src. */
  reloadKey: number
  autoRetries: number
}

/**
 * Load tracking for the IDE iframe. The IDE sometimes comes up blank on the
 * very first load (the server is still starting behind the proxy) and a reload
 * fixes it, so when no load event arrives in time the frame is reloaded with
 * exponential backoff, then hands over to a manual button.
 */
export function useIdeFrameLoad(enabled: boolean) {
  const [state, setState] = useState<FrameLoadState>({
    isLoaded: false,
    reloadKey: 0,
    autoRetries: 0,
  })
  const gaveUp = !state.isLoaded && state.autoRetries >= IDE_MAX_AUTO_RETRIES

  useEffect(() => {
    if (!enabled || state.isLoaded || gaveUp) return
    const timer = setTimeout(
      () =>
        setState((s) => ({ ...s, reloadKey: s.reloadKey + 1, autoRetries: s.autoRetries + 1 })),
      IDE_LOAD_TIMEOUT_MS * 2 ** state.autoRetries,
    )
    return () => clearTimeout(timer)
  }, [enabled, state.isLoaded, state.autoRetries, gaveUp])

  return {
    isLoaded: state.isLoaded,
    reloadKey: state.reloadKey,
    gaveUp,
    onLoad: () => setState((s) => ({ ...s, isLoaded: true })),
    reload: () =>
      setState((s) => ({ isLoaded: false, reloadKey: s.reloadKey + 1, autoRetries: 0 })),
  }
}
