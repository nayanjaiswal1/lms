"use client"

import { useTransition } from "react"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import { endLabSessionAction } from "@/app/(app)/labs/[labId]/actions"
import { isLabAuthError } from "@/lib/labs/auth-error"
import { isLabSessionAlreadyEnded } from "@/lib/labs"
import ROUTES from "@/lib/routes"

/**
 * Ends the session as completed (POST /end), which tears the sandbox down and
 * unlocks the debrief, then opens the result page. An already-ended session
 * counts as success.
 */
export function useFinishLab(sessionId: string, onAuthExpired: () => void) {
  const router = useRouter()
  const [isFinishing, startFinish] = useTransition()

  function finish() {
    startFinish(async () => {
      const res = await endLabSessionAction(sessionId)
      if (!res.ok && !isLabSessionAlreadyEnded(res.code)) {
        const message = res.error ?? "Could not finish the lab. Please try again."
        if (isLabAuthError(res)) onAuthExpired()
        else toast.error(message)
        return
      }
      router.push(ROUTES.labSessionResult(sessionId))
    })
  }

  return { isFinishing, finish }
}
