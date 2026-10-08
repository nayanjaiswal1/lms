"use client"

import { useState, useTransition } from "react"
import { useRouter } from "next/navigation"
import { AlertCircle, Loader2 } from "lucide-react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { endLabSessionAction } from "@/app/(app)/labs/[labId]/actions"
import { isLabSessionAlreadyEnded } from "@/lib/labs"
import ROUTES from "@/lib/routes"

interface DebugIdeUnavailableProps {
  sessionId: string
  labId: string
  /** Re-mints the IDE token; the frame renders again once it succeeds. */
  onRetry: () => Promise<unknown>
}

/**
 * Shown when the IDE token cannot be minted (the session ended or its sandbox
 * is gone). Offers a retry for a transient failure, or ending the session so
 * the student can start a fresh one from the lab page.
 */
export function DebugIdeUnavailable({ sessionId, labId, onRetry }: DebugIdeUnavailableProps) {
  const router = useRouter()
  const [isRetrying, setIsRetrying] = useState(false)
  const [isEnding, startEnd] = useTransition()

  async function retry() {
    setIsRetrying(true)
    try {
      await onRetry()
    } finally {
      setIsRetrying(false)
    }
  }

  function endAndRestart() {
    startEnd(async () => {
      const res = await endLabSessionAction(sessionId)
      if (!res.ok && !isLabSessionAlreadyEnded(res.code)) {
        toast.error(res.error ?? "Could not end the lab. Please try again.")
        return
      }
      router.push(ROUTES.lab(labId))
    })
  }

  const busy = isRetrying || isEnding

  return (
    <div className="empty-state h-full">
      <AlertCircle aria-hidden className="h-6 w-6 text-muted-foreground" />
      <p className="text-sm text-muted-foreground">
        Could not open the IDE. The session may have expired.
      </p>
      <div className="flex flex-wrap justify-center gap-2">
        <Button disabled={busy} size="sm" variant="outline" onClick={retry}>
          {isRetrying && <Loader2 aria-hidden className="mr-1.5 h-3.5 w-3.5 animate-spin" />}
          Try again
        </Button>
        <Button disabled={busy} size="sm" onClick={endAndRestart}>
          {isEnding && <Loader2 aria-hidden className="mr-1.5 h-3.5 w-3.5 animate-spin" />}
          End lab and start fresh
        </Button>
      </div>
    </div>
  )
}
