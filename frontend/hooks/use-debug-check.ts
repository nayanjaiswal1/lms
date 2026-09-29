"use client"

import { useState, useTransition } from "react"
import { getLabSessionAction, submitLabAction } from "@/app/(app)/labs/[labId]/actions"
import { isLabAuthError } from "@/lib/labs/auth-error"
import { DEBUG_CHECK_COOLDOWN_SECONDS } from "@/lib/labs/kinds/debug"
import { parseCheckFailures, type CheckFailure } from "@/lib/labs/kinds/debug-results"
import type { TaskCompletion } from "@/lib/labs"

export type CheckProblem = "busy" | "auth" | "error"

interface CheckState {
  completions: TaskCompletion[]
  score: number
  /** Failing checks from the last Check, per task. */
  failures: Record<string, CheckFailure[]>
  problem: CheckProblem | null
  message: string | null
  /** Epoch ms until which the server refuses another Check (0 = none). */
  cooldownUntil: number
}

interface UseDebugCheckOptions {
  sessionId: string
  initialCompletions: TaskCompletion[]
  initialScore: number
  onScoreChange?: (score: number) => void
  onAuthExpired?: () => void
  onSessionCompleted: () => void
}

/**
 * The debug lab's Check button: batch-grades every pending task in a clean
 * room (POST /submit), then re-reads the session for authoritative
 * completions/score. 429 = the 30 s cooldown, 503 = grader at capacity.
 */
export function useDebugCheck({
  sessionId,
  initialCompletions,
  initialScore,
  onScoreChange,
  onAuthExpired,
  onSessionCompleted,
}: UseDebugCheckOptions) {
  const [state, setState] = useState<CheckState>({
    completions: initialCompletions,
    score: initialScore,
    failures: {},
    problem: null,
    message: null,
    cooldownUntil: 0,
  })
  const [isChecking, startCheck] = useTransition()

  // Re-reads completions + score (also after a write-up review, whose
  // response doesn't say which task it passed).
  async function sync(): Promise<void> {
    const res = await getLabSessionAction(sessionId)
    if (!res.ok || !res.data) return
    const { session, task_completions } = res.data
    setState((prev) => ({ ...prev, completions: task_completions, score: session.score }))
    onScoreChange?.(session.score)
  }

  function check() {
    startCheck(async () => {
      const res = await submitLabAction(sessionId)
      if (res.status === 429) {
        setState((prev) => ({
          ...prev,
          problem: null,
          message: null,
          cooldownUntil: Date.now() + DEBUG_CHECK_COOLDOWN_SECONDS * 1000,
        }))
        return
      }
      if (res.status === 503) {
        setState((prev) => ({ ...prev, problem: "busy", message: res.error ?? null }))
        return
      }
      if (!res.ok || !res.data) {
        const message = res.error ?? "Check failed. Please try again."
        if (isLabAuthError(message)) onAuthExpired?.()
        setState((prev) => ({
          ...prev,
          problem: isLabAuthError(message) ? "auth" : "error",
          message,
        }))
        return
      }
      const { results, session_completed } = res.data
      const failures: Record<string, CheckFailure[]> = {}
      for (const r of results) {
        if (!r.passed) failures[r.task_id] = parseCheckFailures(r.stdout)
      }
      setState((prev) => ({
        ...prev,
        failures,
        problem: null,
        message: null,
        cooldownUntil: Date.now() + DEBUG_CHECK_COOLDOWN_SECONDS * 1000,
      }))
      await sync()
      if (session_completed) onSessionCompleted()
    })
  }

  return { ...state, isChecking, check, sync }
}
