"use client"

import { useCallback, useState } from "react"
import { runLabScriptAction, submitLabAction } from "@/app/(app)/labs/[labId]/actions"
import type { LabRunResult, LabSubmitResult } from "@/lib/labs"

interface RunSubmitState {
  runResult: LabRunResult | null
  submitResult: LabSubmitResult | null
  error: string | null
  busy: "run" | "submit" | null
}

interface UseLabRunSubmitReturn extends RunSubmitState {
  run: () => void
  submit: () => void
}

/**
 * Drives the sandbox workspace's HackerEarth-style actions: Run executes the
 * lab's visible sample tests (unscored), Submit batch-verifies every hidden
 * task script. One state object keeps the last result of each visible while
 * the other action runs.
 */
export function useLabRunSubmit(
  sessionId: string,
  onSubmitted?: (result: LabSubmitResult) => void,
): UseLabRunSubmitReturn {
  const [state, setState] = useState<RunSubmitState>({
    runResult: null,
    submitResult: null,
    error: null,
    busy: null,
  })

  const run = useCallback(() => {
    setState((s) => ({ ...s, busy: "run", error: null }))
    void runLabScriptAction(sessionId).then((res) => {
      setState((s) => ({
        ...s,
        busy: null,
        runResult: res.ok && res.data ? res.data : s.runResult,
        error: res.ok ? null : (res.error ?? "Run failed."),
      }))
    })
  }, [sessionId])

  const submit = useCallback(() => {
    setState((s) => ({ ...s, busy: "submit", error: null }))
    void submitLabAction(sessionId).then((res) => {
      setState((s) => ({
        ...s,
        busy: null,
        submitResult: res.ok && res.data ? res.data : s.submitResult,
        error: res.ok ? null : (res.error ?? "Submit failed."),
      }))
      if (res.ok && res.data) onSubmitted?.(res.data)
    })
  }, [sessionId, onSubmitted])

  return { ...state, run, submit }
}
