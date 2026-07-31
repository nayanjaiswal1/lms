"use client"

import { useEffect } from "react"
import { useRouter, usePathname } from "next/navigation"
import { toast } from "sonner"
import { useLabProvisioning } from "@/lib/labs/provisioning-context"
import ROUTES from "@/lib/routes"

const REDIRECT_COUNTDOWN_SECONDS = 3
// Must stay above backend's labs.ProvisionTimeoutSeconds (180s) — nested-
// Docker labs on a proxied-socket host (Docker Desktop) can legitimately
// take close to that full budget (a doomed scoped attempt runs to
// completion before the privileged retry boots dockerd for real).
const PROVISION_SAFETY_TIMEOUT_MS = 200_000

type ReadinessEvent = { type: "ready" | "failed" }

// Mounted once in the root layout. While the tracked session is provisioning,
// reports progress via toast instead of a full-page blocking screen, so the
// user can keep browsing until the lab container is ready. Once running or
// paused, ActiveLabsBar takes over — this component has nothing left to watch.
export function LabProvisioningWatcher() {
  const { session, updateStatus, clear } = useLabProvisioning()
  const router = useRouter()
  const pathname = usePathname()
  // Course learn pages host their own inline LabReadinessWait + router.refresh()
  // flow (see ModuleLabClient) — this watcher must still sync context status
  // via SSE there, but must never toast/redirect on top of it, or "ready"
  // yanks the user off the course page into the standalone session route.
  const isInlineHosted = pathname.startsWith("/courses/") && pathname.includes("/learn/")

  // Keyed on session_id alone — NOT on session.status. This effect's own
  // updateStatus() call (provisioning -> running) below would otherwise
  // change `session` and re-trigger this effect mid-flight, tearing down the
  // countdown timer it had just started. session_id never changes for a
  // given session, so the effect body reads `session` once (at the render
  // that introduced this session_id) and manages its own lifecycle from
  // there without needing to react to further status changes it causes itself.
  const sessionId = session?.session_id ?? null

  useEffect(() => {
    if (!sessionId || !session || session.status !== "provisioning") return

    const labId = session.lab_id
    const toastId = `lab-provisioning-${sessionId}`
    const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? ""

    let countdownTimer: ReturnType<typeof setInterval> | null = null
    let safetyTimer: ReturnType<typeof setTimeout> | null = null

    const stopTimers = () => {
      if (countdownTimer) clearInterval(countdownTimer)
      if (safetyTimer) clearTimeout(safetyTimer)
    }

    const openSession = () => {
      stopTimers()
      toast.dismiss(toastId)
      router.push(ROUTES.labSession(sessionId))
    }

    const reportFailed = () => {
      stopTimers()
      toast.error("Lab failed to start", {
        id: toastId,
        description: "The lab environment could not be provisioned. This is usually a temporary infrastructure issue.",
        duration: 8000,
        action: { label: "Try again", onClick: () => router.push(ROUTES.lab(labId)) },
      })
      clear(sessionId)
    }

    const startCountdown = () => {
      let remaining = REDIRECT_COUNTDOWN_SECONDS

      const renderCountdown = () => {
        toast.success("Lab environment ready", {
          id: toastId,
          description: `Opening in ${remaining}s…`,
          duration: Infinity,
          action: { label: "Open now", onClick: openSession },
          cancel: {
            label: "Stay here",
            onClick: () => {
              stopTimers()
              toast.success("Lab environment ready", {
                id: toastId,
                description: "Click to open it whenever you're ready.",
                duration: Infinity,
                action: { label: "Open", onClick: openSession },
              })
            },
          },
        })
      }

      renderCountdown()
      countdownTimer = setInterval(() => {
        remaining -= 1
        if (remaining <= 0) {
          openSession()
          return
        }
        renderCountdown()
      }, 1000)
    }

    if (!isInlineHosted) {
      toast.loading("Provisioning your lab environment…", {
        id: toastId,
        description: "This usually takes 10–30 seconds. Feel free to keep browsing.",
        duration: Infinity,
        action: {
          label: "View",
          onClick: () => {
            stopTimers()
            toast.dismiss(toastId)
            router.push(ROUTES.labSession(sessionId))
          },
        },
      })
    }

    const es = new EventSource(`${apiUrl}/api/labs/sessions/${sessionId}/events`, {
      withCredentials: true,
    })

    es.onmessage = (e: MessageEvent) => {
      const data = JSON.parse(e.data as string) as ReadinessEvent
      if (data.type === "ready") {
        es.close()
        stopTimers()
        updateStatus(sessionId, "running")
        if (isInlineHosted) {
          toast.dismiss(toastId)
        } else {
          startCountdown()
        }
      } else if (data.type === "failed") {
        es.close()
        reportFailed()
      }
    }

    // The connection can drop for transient reasons (proxy hiccup, brief
    // network loss); the browser retries EventSource automatically, so we
    // don't treat onerror as a hard failure. The safety timeout below is the
    // real backstop against a lab that never resolves.
    safetyTimer = setTimeout(reportFailed, PROVISION_SAFETY_TIMEOUT_MS)

    return () => {
      stopTimers()
      es.close()
    }
    // `session` is intentionally excluded: this effect must key on sessionId
    // alone (see comment above `sessionId`'s declaration) — reacting to
    // session.status changes here is exactly the bug this is avoiding.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sessionId, router, updateStatus, clear, isInlineHosted])

  return null
}
