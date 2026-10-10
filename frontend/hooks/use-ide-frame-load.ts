"use client"

import { useEffect, useState } from "react"

/** First wait for the IDE's load event; doubles on every automatic retry. */
const IDE_LOAD_TIMEOUT_MS = 12_000
/** First wait before re-probing an unreachable IDE; doubles on every retry. */
const IDE_PROBE_RETRY_MS = 3_000
/** Silent reloads before the student is asked to reload by hand. */
const IDE_MAX_AUTO_RETRIES = 3

interface FrameLoadState {
  /** The IDE URL answered the pre-flight probe; the iframe may mount. */
  isReachable: boolean
  isLoaded: boolean
  /** Bumped on every reload; used as the iframe key and to pick a fresh-token src. */
  reloadKey: number
  autoRetries: number
}

/**
 * Load tracking for the IDE iframe. A no-cors probe runs first so the iframe
 * is never mounted while the proxy is unreachable (an error page would fire a
 * `load` event and look like success). The probe response is opaque, so HTTP
 * status is unreadable across the labproxy/preview origins (no CORS headers);
 * only network failures are caught. After mounting, the IDE sometimes comes up
 * blank on first load and a reload fixes it, so a missing load event reloads
 * with exponential backoff, then hands over to a manual button.
 */
export function useIdeFrameLoad(url: string | null) {
  const [state, setState] = useState<FrameLoadState>({
    isReachable: false,
    isLoaded: false,
    reloadKey: 0,
    autoRetries: 0,
  })
  const enabled = !!url
  const gaveUp = !state.isLoaded && state.autoRetries >= IDE_MAX_AUTO_RETRIES

  useEffect(() => {
    if (!url || state.isReachable || gaveUp) return
    let cancelled = false
    let retry: ReturnType<typeof setTimeout> | undefined
    fetch(url, { mode: "no-cors", cache: "no-store" })
      .then(() => {
        if (!cancelled) setState((s) => ({ ...s, isReachable: true }))
      })
      .catch(() => {
        retry = setTimeout(
          () => setState((s) => ({ ...s, autoRetries: s.autoRetries + 1 })),
          IDE_PROBE_RETRY_MS * 2 ** state.autoRetries,
        )
      })
    return () => {
      cancelled = true
      clearTimeout(retry)
    }
  }, [url, state.isReachable, state.autoRetries, gaveUp])

  useEffect(() => {
    if (!enabled || !state.isReachable || state.isLoaded || gaveUp) return
    const timer = setTimeout(
      () =>
        setState((s) => ({ ...s, reloadKey: s.reloadKey + 1, autoRetries: s.autoRetries + 1 })),
      IDE_LOAD_TIMEOUT_MS * 2 ** state.autoRetries,
    )
    return () => clearTimeout(timer)
  }, [enabled, state.isReachable, state.isLoaded, state.autoRetries, gaveUp])

  return {
    isReachable: state.isReachable,
    isLoaded: state.isLoaded,
    reloadKey: state.reloadKey,
    gaveUp,
    onLoad: () => setState((s) => ({ ...s, isLoaded: true })),
    reload: () =>
      setState((s) => ({
        isReachable: false,
        isLoaded: false,
        reloadKey: s.reloadKey + 1,
        autoRetries: 0,
      })),
  }
}
