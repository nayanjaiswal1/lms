"use client"

import { useState, useTransition, useCallback } from "react"
import { requestLabHintAction } from "@/app/(app)/labs/[labId]/actions"
import {
  MAX_HINTS_PER_TASK,
  isLabCompletedAtDeadline,
  isLabSessionExpired,
  type TaskCompletion,
} from "@/lib/labs"

export interface RevealedHint {
  level: number
  content: string
}

// useLabHint owns the AI hint drawer's client-side state: which task's
// drawer is open, the hints revealed so far per task (the backend has no
// "re-fetch a previous level" endpoint — POST .../hint always advances to
// the next level — so once revealed, a hint's text is kept here for the
// rest of the session), and the in-flight request.
export function useLabHint(
  sessionId: string,
  initialCompletions: TaskCompletion[],
  /** The deadline passed while the hint was requested (kind workspaces route to the result). */
  onDeadline?: (outcome: "completed" | "expired") => void,
) {
  const [hintsByTask, setHintsByTask] = useState<Record<string, RevealedHint[]>>({})
  const [openTaskId, setOpenTaskId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [isRequesting, startRequest] = useTransition()

  // Falls back to the session's own initial hints_used (from a resumed
  // session) when nothing has been revealed client-side yet this page load
  // — so the "X/3 used" count and the disabled state are correct even
  // before the student opens the drawer, though the earlier hints' TEXT is
  // only available for hints revealed in this browser session.
  const hintsUsedFor = useCallback(
    (taskId: string): number => {
      const revealed = hintsByTask[taskId]
      if (revealed && revealed.length > 0) return revealed.length
      return initialCompletions.find((c) => c.task_id === taskId)?.hints_used ?? 0
    },
    [hintsByTask, initialCompletions],
  )

  function requestHint(taskId: string) {
    setError(null)
    // Same key for every click made while the task is at the same level, so
    // a double-submit can never consume two levels.
    const idempotencyKey = `hint-${sessionId}-${taskId}-${hintsUsedFor(taskId) + 1}`
    startRequest(async () => {
      const res = await requestLabHintAction(sessionId, taskId, idempotencyKey)
      if (isLabCompletedAtDeadline(res.code)) {
        onDeadline?.("completed")
        return
      }
      if (isLabSessionExpired(res.code)) {
        onDeadline?.("expired")
        return
      }
      if (!res.ok || !res.data) {
        setError(res.error ?? "Could not get a hint. Please try again.")
        return
      }
      const { level, content } = res.data
      setHintsByTask((prev) => {
        const existing = prev[taskId] ?? []
        if (existing.some((h) => h.level === level)) return prev
        return { ...prev, [taskId]: [...existing, { level, content }] }
      })
    })
  }

  return {
    openTaskId,
    openDrawer: setOpenTaskId,
    closeDrawer: () => setOpenTaskId(null),
    hintsByTask,
    hintsUsedFor,
    requestHint,
    isRequesting,
    error,
    dismissError: () => setError(null),
    maxHints: MAX_HINTS_PER_TASK,
  }
}
