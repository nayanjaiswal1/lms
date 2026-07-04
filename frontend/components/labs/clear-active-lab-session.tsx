"use client"

import { useEffect } from "react"
import { useLabProvisioning } from "@/lib/labs/provisioning-context"

interface ClearActiveLabSessionProps {
  sessionId: string
}

// Reaching the result page always means this session is terminal server-side —
// whether the user ended it themselves, it auto-expired while they were
// elsewhere, or they clicked "Resume" on a stale ActiveLabsBar entry and got
// redirected here instead. LabProvisioningContext is seeded once in the root
// layout and never refetched on client-side navigation, so nothing else
// clears its stale "running" entry for this session. No server-component or
// URL-state equivalent exists for syncing this client-only global store.
export function ClearActiveLabSession({ sessionId }: ClearActiveLabSessionProps) {
  const { clear } = useLabProvisioning()

  useEffect(() => {
    clear(sessionId)
  }, [sessionId, clear])

  return null
}
