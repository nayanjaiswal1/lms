"use client"

import { useEffect, useRef } from "react"

interface UseLabReadinessOptions {
  onReady: () => void
  onFailed: () => void
}

// Safety backstop against a lab that never resolves — must clear the
// longest legitimate provisioning path server-side (see
// labs.ProvisionTimeoutSeconds, 180s: nested-Docker labs on a proxied-
// socket host run a doomed scoped attempt to completion before their
// privileged retry boots dockerd for real).
const PROVISION_SAFETY_TIMEOUT_MS = 200_000

// Watches a provisioning lab session over SSE until it's ready or failed.
// Shared by <LabReadinessWait> (full-screen, the dedicated /labs/sessions
// route) and <LabReadinessInline> (course-page footprint) — same wait
// mechanics, different chrome around it.
export function useLabReadiness(sessionId: string, { onReady, onFailed }: UseLabReadinessOptions) {
  const onReadyRef = useRef(onReady)
  const onFailedRef = useRef(onFailed)
  onReadyRef.current = onReady
  onFailedRef.current = onFailed

  useEffect(() => {
    // Relative same-origin URL, proxied to the backend by next.config.ts's
    // rewrites() — a direct cross-site EventSource to NEXT_PUBLIC_API_URL
    // never carries the SameSite=Lax auth cookie, same root cause as
    // lib/client/api.ts's apiFetch.
    const es = new EventSource(`/api/labs/sessions/${sessionId}/events`, {
      withCredentials: true,
    })

    const safetyTimer = setTimeout(() => onFailedRef.current(), PROVISION_SAFETY_TIMEOUT_MS)

    es.onmessage = (e: MessageEvent) => {
      const data = JSON.parse(e.data as string) as { type: string }
      if (data.type === "ready") {
        clearTimeout(safetyTimer)
        es.close()
        onReadyRef.current()
      } else if (data.type === "failed") {
        clearTimeout(safetyTimer)
        es.close()
        onFailedRef.current()
      }
    }

    // The connection can drop for transient reasons (proxy hiccup, brief
    // network loss); the browser retries EventSource automatically, so this
    // must not be treated as a hard failure — the safety timeout above is
    // the real backstop. See the identical comment in
    // lab-provisioning-watcher.tsx, which this mirrors.

    return () => {
      clearTimeout(safetyTimer)
      es.close()
    }
  }, [sessionId])
}
