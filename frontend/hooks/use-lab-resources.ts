"use client"

import { useState, useTransition } from "react"
import { toast } from "sonner"
import { getLabResourcesAction } from "@/app/(app)/labs/sessions/[sessionId]/files-actions"
import type { LabResourcesData } from "@/lib/labs/files"

// Refresh-on-demand only — no watch/stream, per the plan's scope for the
// resources panel. Fetched on first tab open and on explicit Refresh clicks.
export function useLabResources(sessionId: string) {
  const [resources, setResources] = useState<LabResourcesData | null>(null)
  const [hasLoaded, setHasLoaded] = useState(false)
  const [isLoading, startLoad] = useTransition()

  function refresh() {
    startLoad(async () => {
      const res = await getLabResourcesAction(sessionId)
      setHasLoaded(true)
      if (!res.ok || !res.data) {
        toast.error(res.error ?? "Failed to load cluster resources.")
        return
      }
      setResources(res.data)
    })
  }

  return { resources, hasLoaded, isLoading, refresh }
}
