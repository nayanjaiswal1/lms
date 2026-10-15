"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import { useDebugCheck } from "@/hooks/use-debug-check"
import { useLabHint } from "@/hooks/use-lab-hint"
import { useWriteupReview } from "@/hooks/use-writeup-review"
import ROUTES from "@/lib/routes"
import type { LabKindWorkspaceProps } from "@/components/labs/kinds/workspace-registry"

type DebugSessionOptions = Pick<
  LabKindWorkspaceProps,
  "session" | "lab" | "initialCompletions" | "resetNonce" | "onScoreChange" | "onAuthExpiredChange"
>

/**
 * State shared by both debug workspaces (classic and mission): the batch
 * Check, the write-up review and the hint ladder, wired to the same
 * session-expiry and result-page handling. A server-side reset bumps
 * resetNonce, which the workspace uses as its key so all of this restarts.
 */
export function useDebugSession({
  session,
  lab,
  initialCompletions,
  resetNonce,
  onScoreChange,
  onAuthExpiredChange,
}: DebugSessionOptions) {
  const router = useRouter()
  const [isAuthExpired, setIsAuthExpired] = useState(false)
  const isFresh = resetNonce > 0

  const expireAuth = () => {
    setIsAuthExpired(true)
    onAuthExpiredChange?.(true)
  }
  const goToResult = () => router.push(ROUTES.labSessionResult(session.id))
  // The deadline hit while a request was in flight: a completed lab is a
  // success (debrief), an expired one still lands on its result page.
  const onDeadline = (outcome: "completed" | "expired") => {
    toast(
      outcome === "completed"
        ? "Time's up — your lab was completed."
        : "Time's up — this lab session expired.",
    )
    goToResult()
  }
  const check = useDebugCheck({
    sessionId: session.id,
    tasks: lab.tasks,
    initialCompletions: isFresh ? [] : initialCompletions,
    initialScore: isFresh ? 0 : session.score,
    onScoreChange,
    onAuthExpired: expireAuth,
    onSessionCompleted: goToResult,
    onDeadline,
  })
  const writeup = useWriteupReview((result) => {
    if (result.passed) check.applyWriteupPass(result.score_added)
    if (result.session_completed) goToResult()
  }, onDeadline)
  const hint = useLabHint(session.id, check.completions, onDeadline)

  const passedCount = check.completions.filter((c) => c.status === "passed").length
  const hintsUsedByTask = Object.fromEntries(
    lab.tasks.map((t) => [t.task_id, hint.hintsUsedFor(t.task_id)]),
  )

  return { isAuthExpired, expireAuth, goToResult, check, writeup, hint, passedCount, hintsUsedByTask }
}
