"use client"

import { useCallback, useEffect, useState } from "react"
import { listLabPortsAction } from "@/app/(app)/labs/[labId]/actions"
import type { LabPort } from "@/lib/labs"

const POLL_INTERVAL_MS = 5000

interface UseLabPortsReturn {
  ports: LabPort[]
  refresh: () => void
}

/**
 * Polls the listening TCP ports inside the session container every 5s while
 * `enabled` and the tab is visible. The visibility gate matters beyond
 * politeness: the backend resumes a paused container on every poll, so a
 * backgrounded tab polling forever would defeat idle-pause entirely.
 */
export function useLabPorts(sessionId: string, enabled: boolean): UseLabPortsReturn {
  const [ports, setPorts] = useState<LabPort[]>([])

  const refresh = useCallback(() => {
    void listLabPortsAction(sessionId).then((res) => {
      if (res.ok && res.data) setPorts(res.data.ports)
    })
  }, [sessionId])

  useEffect(() => {
    if (!enabled) return

    const tick = () => {
      if (!document.hidden) refresh()
    }
    tick()
    const interval = setInterval(tick, POLL_INTERVAL_MS)
    return () => clearInterval(interval)
  }, [enabled, refresh])

  return { ports, refresh }
}
