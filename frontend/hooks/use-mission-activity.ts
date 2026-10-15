"use client"

import { useEffect } from "react"
import { apiFetch } from "@/lib/client/api"
import {
  ACTIVITY_FLUSH_INTERVAL_MS,
  ACTIVITY_MAX_BATCH,
  ACTIVITY_MIN_AWAY_MS,
  ACTIVITY_TYPE,
  type ActivityEventInput,
} from "@/lib/labs/kinds/debug-mission"

// Bounds the retry queue when the endpoint keeps refusing (session ended, offline).
const MAX_QUEUED_EVENTS = 200

/**
 * Reports what the browser can see of the attempt to the activity endpoint:
 * time spent in another tab and pastes into this page. File opens and large
 * inserts inside the IDE (a cross-origin frame) are captured in the sandbox
 * and stored when the session closes (backend activity_capture.go).
 * Batched; flushed on an interval and whenever the tab is hidden.
 */
export function useMissionActivity(sessionId: string, enabled: boolean) {
  useEffect(() => {
    if (!enabled) return

    let queue: ActivityEventInput[] = []
    let hiddenAt: number | null = null

    const flush = async (keepalive: boolean) => {
      if (queue.length === 0) return
      const batch = queue.slice(0, ACTIVITY_MAX_BATCH)
      queue = queue.slice(batch.length)
      const res = await apiFetch<{ ok: boolean }>(`/labs/sessions/${sessionId}/activity`, {
        method: "POST",
        body: JSON.stringify({ events: batch }),
        keepalive,
      })
      if (res === null) queue = [...batch, ...queue].slice(0, MAX_QUEUED_EVENTS)
    }

    const onVisibility = () => {
      if (document.hidden) {
        hiddenAt = Date.now()
        void flush(true)
        return
      }
      if (hiddenAt === null) return
      const away = Date.now() - hiddenAt
      hiddenAt = null
      if (away >= ACTIVITY_MIN_AWAY_MS) queue.push({ type: ACTIVITY_TYPE.TAB_AWAY, detail: "", value: away })
    }
    const onPaste = (e: ClipboardEvent) => {
      const chars = e.clipboardData?.getData("text").length ?? 0
      if (chars > 0) queue.push({ type: ACTIVITY_TYPE.PASTE, detail: "", value: chars })
    }

    document.addEventListener("visibilitychange", onVisibility)
    document.addEventListener("paste", onPaste, true)
    const timer = setInterval(() => void flush(false), ACTIVITY_FLUSH_INTERVAL_MS)
    return () => {
      clearInterval(timer)
      document.removeEventListener("visibilitychange", onVisibility)
      document.removeEventListener("paste", onPaste, true)
      void flush(true)
    }
  }, [sessionId, enabled])
}
