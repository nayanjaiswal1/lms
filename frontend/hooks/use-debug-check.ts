"use client"

import { useRef, useState } from "react"
import { submitLabAction } from "@/app/(app)/labs/[labId]/actions"
import { isLabAuthError } from "@/lib/labs/auth-error"
import { LAB_CHECK_CLIENT_TIMEOUT_MS, LAB_ERROR_CODES, isLabCompletedAtDeadline, isLabSessionExpired } from "@/lib/labs"
import { parseCheckFailures, type CheckFailure } from "@/lib/labs/kinds/debug-results"
import type { LabSubmitResult, LabSubmitTaskResult, LabTask, TaskCompletion } from "@/lib/labs"
import type { ActionResult } from "@/lib/server/api"

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
  tasks: LabTask[]
  initialCompletions: TaskCompletion[]
  initialScore: number
  onScoreChange?: (score: number) => void
  onAuthExpired?: () => void
  onSessionCompleted: () => void
  /** The deadline passed while the request was in flight (410 completed / expired). */
  onDeadline: (outcome: "completed" | "expired") => void
}

// Folds one batch's per-task outcomes into the completions list.
function mergeResults(prev: TaskCompletion[], results: LabSubmitTaskResult[]): TaskCompletion[] {
  const byId = new Map(prev.map((c) => [c.task_id, c]))
  for (const r of results) {
    const cur = byId.get(r.task_id)
    byId.set(r.task_id, {
      task_id: r.task_id,
      hints_used: cur?.hints_used ?? 0,
      attempts: (cur?.attempts ?? 0) + 1,
      status: r.passed ? "passed" : (cur?.status ?? "pending"),
    })
  }
  return [...byId.values()]
}

function markPassed(prev: TaskCompletion[], taskId: string): TaskCompletion[] {
  const cur = prev.find((c) => c.task_id === taskId)
  const passed: TaskCompletion = {
    task_id: taskId,
    attempts: cur?.attempts ?? 1,
    hints_used: cur?.hints_used ?? 0,
    status: "passed",
  }
  return cur ? prev.map((c) => (c.task_id === taskId ? passed : c)) : [...prev, passed]
}

const CHECK_UNREACHABLE: ActionResult<LabSubmitResult> = {
  error: "The check could not finish. Your work is safe — try again.",
}

// Server actions can throw (Next's "unexpected response" when the connection
// drops) or never settle on a hung proxy; both must end as a retryable error,
// never a spinner that only a reload clears.
async function submitWithTimeout(sessionId: string): Promise<ActionResult<LabSubmitResult>> {
  let timer: ReturnType<typeof setTimeout> | undefined
  const timeout = new Promise<ActionResult<LabSubmitResult>>((resolve) => {
    timer = setTimeout(() => resolve(CHECK_UNREACHABLE), LAB_CHECK_CLIENT_TIMEOUT_MS)
  })
  try {
    return await Promise.race([submitLabAction(sessionId).catch(() => CHECK_UNREACHABLE), timeout])
  } finally {
    clearTimeout(timer)
  }
}

/**
 * The debug lab's Check button: batch-grades every pending task in a clean
 * room (POST /submit). 429 carries the cooldown's Retry-After, 503 means the
 * grader is at capacity. State is folded from the response, no re-fetch.
 */
export function useDebugCheck({
  sessionId,
  tasks,
  initialCompletions,
  initialScore,
  onScoreChange,
  onAuthExpired,
  onSessionCompleted,
  onDeadline,
}: UseDebugCheckOptions) {
  const [state, setState] = useState<CheckState>({
    completions: initialCompletions,
    score: initialScore,
    failures: {},
    problem: null,
    message: null,
    cooldownUntil: 0,
  })
  // A plain flag, not a transition: the pending state must paint on the click
  // itself, and the ref makes a second click in the same frame a no-op.
  const [isChecking, setIsChecking] = useState(false)
  const inFlight = useRef(false)

  const requiredPassed = tasks
    .filter((t) => !t.is_optional)
    .every((t) => state.completions.some((c) => c.task_id === t.task_id && c.status === "passed"))

  // Applies a passed write-up review (the task is identified by its grader).
  function applyWriteupPass(scoreAdded: number) {
    const task = tasks.find((t) => t.grader === "writeup_review")
    if (!task || scoreAdded < 0) return
    setState((prev) => ({
      ...prev,
      score: prev.score + scoreAdded,
      completions: markPassed(prev.completions, task.task_id),
    }))
    onScoreChange?.(state.score + scoreAdded)
  }

  async function check() {
    if (inFlight.current) return
    inFlight.current = true
    setIsChecking(true)
    try {
      const res = await submitWithTimeout(sessionId)
      if (res.code === LAB_ERROR_CODES.rateLimited) {
        setState((prev) => ({
          ...prev,
          problem: null,
          message: null,
          cooldownUntil: Date.now() + (res.retryAfter ?? 1) * 1000,
        }))
        return
      }
      if (isLabCompletedAtDeadline(res.code)) {
        onDeadline("completed")
        return
      }
      if (isLabSessionExpired(res.code)) {
        onDeadline("expired")
        return
      }
      if (res.code === LAB_ERROR_CODES.graderBusy) {
        setState((prev) => ({ ...prev, problem: "busy", message: res.error ?? null }))
        return
      }
      if (!res.ok || !res.data) {
        const message = res.error ?? "Check failed. Please try again."
        if (isLabAuthError(res)) onAuthExpired?.()
        setState((prev) => ({
          ...prev,
          problem: isLabAuthError(res) ? "auth" : "error",
          message,
        }))
        return
      }
      const { results, score, session_completed } = res.data
      const failures: Record<string, CheckFailure[]> = {}
      for (const r of results) {
        if (!r.passed) failures[r.task_id] = parseCheckFailures(r.stdout)
      }
      setState((prev) => ({
        ...prev,
        completions: mergeResults(prev.completions, results),
        score,
        failures,
        problem: null,
        message: null,
      }))
      onScoreChange?.(score)
      if (session_completed) onSessionCompleted()
    } finally {
      inFlight.current = false
      setIsChecking(false)
    }
  }

  return { ...state, isChecking, check, requiredPassed, applyWriteupPass }
}
