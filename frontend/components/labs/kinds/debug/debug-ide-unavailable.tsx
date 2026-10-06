"use client"

import { useTransition } from "react"
import { useRouter } from "next/navigation"
import { AlertCircle, Loader2, RotateCcw } from "lucide-react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { endLabSessionAction } from "@/app/(app)/labs/[labId]/actions"
import { isLabSessionAlreadyEnded } from "@/lib/labs"
import ROUTES from "@/lib/routes"

interface DebugIdeUnavailableProps {
  sessionId: string
}

/**
 * Shown when the IDE token cannot be minted: the session expired or its
 * container is gone. Names that plainly and offers the way out — end the
 * orphaned session (which frees the one-active-lab slot) and start a fresh one.
 */
export function DebugIdeUnavailable({ sessionId }: DebugIdeUnavailableProps) {
  const router = useRouter()
  const [isEnding, startEnd] = useTransition()

  function endAndRestart() {
    startEnd(async () => {
      const res = await endLabSessionAction(sessionId)
      if (!res.ok && !isLabSessionAlreadyEnded(res.code)) {
        toast.error(res.error ?? "Could not end the lab. Please try again.")
        return
      }
      router.push(ROUTES.LABS_CATALOG)
    })
  }

  return (
    <div className="empty-state h-full" role="alert">
      <AlertCircle aria-hidden className="h-6 w-6 text-muted-foreground" />
      <p className="text-sm font-medium">This lab session is no longer running</p>
      <p className="max-w-sm text-sm text-muted-foreground">
        The session expired or its sandbox was shut down, so the IDE cannot connect. End it to
        free your lab slot, then start a fresh one from the catalog.
      </p>
      <div className="flex flex-wrap justify-center gap-2">
        <Button className="touch-target gap-2" variant="outline" onClick={() => window.location.reload()}>
          <RotateCcw aria-hidden className="h-4 w-4" />
          Try again
        </Button>
        <Button className="touch-target gap-2" disabled={isEnding} onClick={endAndRestart}>
          {isEnding && <Loader2 aria-hidden className="h-4 w-4 animate-spin" />}
          End lab and start fresh
        </Button>
      </div>
    </div>
  )
}
