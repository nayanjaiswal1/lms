"use client"

import { useCallback, useEffect, useState } from "react"

interface UseLabNavigationGuardOptions {
  enabled: boolean
  onConfirmLeave: () => void
}

// Attaches native window listeners to keep the student inside an active lab
// session: beforeunload warns on tab close/refresh, and a trapped history
// entry intercepts the browser back button with a custom confirm dialog
// instead of silently dropping the session. No server-component or
// hook-library equivalent exists for either browser API.
export function useLabNavigationGuard({ enabled, onConfirmLeave }: UseLabNavigationGuardOptions) {
  const [showLeaveConfirm, setShowLeaveConfirm] = useState(false)

  useEffect(() => {
    if (!enabled) return

    const onBeforeUnload = (e: BeforeUnloadEvent) => {
      e.preventDefault()
      e.returnValue = ""
    }

    window.history.pushState(null, "", window.location.href)
    const onPopState = () => {
      window.history.pushState(null, "", window.location.href)
      setShowLeaveConfirm(true)
    }

    window.addEventListener("beforeunload", onBeforeUnload)
    window.addEventListener("popstate", onPopState)

    return () => {
      window.removeEventListener("beforeunload", onBeforeUnload)
      window.removeEventListener("popstate", onPopState)
    }
  }, [enabled])

  const confirmLeave = useCallback(() => {
    setShowLeaveConfirm(false)
    onConfirmLeave()
  }, [onConfirmLeave])

  const cancelLeave = useCallback(() => {
    setShowLeaveConfirm(false)
  }, [])

  return { showLeaveConfirm, confirmLeave, cancelLeave }
}
