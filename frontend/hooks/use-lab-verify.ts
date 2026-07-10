"use client"

import { useState, useTransition, useRef, useCallback } from "react"
import { toast } from "sonner"
import { verifyLabTaskAction } from "@/app/(app)/labs/[labId]/actions"
import type { TaskCompletion, LabCodeLanguage } from "@/lib/labs"

export interface LabRunResult {
  passed: boolean
  stdout: string
  stderr: string
}

const STARTER_CODE: Record<LabCodeLanguage, string> = {
  javascript: "// Write your solution here\n\n",
  python: "# Write your solution here\n\n",
  typescript: "// Write your solution here\n\n",
}

function isAuthError(msg: string): boolean {
  const lower = msg.toLowerCase()
  return (
    lower.includes("invalid or expired") ||
    lower.includes("unauthorized") ||
    lower.includes("not authenticated") ||
    lower.includes("session expired")
  )
}

export function useLabVerify(
  sessionId: string,
  initialCompletions: TaskCompletion[],
  initialScore: number,
  labLanguage: LabCodeLanguage | null,
  initialTaskId: string | null,
) {
  // A lab with a language on record is locked to it — the editor must never
  // let the student switch away from the language the task's verification
  // script was actually authored in. Only a lab with no language on record
  // (legacy/unset) falls back to a student-selectable default.
  const isLanguageLocked = labLanguage !== null
  const initialLanguage = labLanguage ?? "javascript"

  const [completions, setCompletions] = useState<TaskCompletion[]>(initialCompletions)
  const [score, setScore] = useState(initialScore)
  const [code, setCode] = useState(STARTER_CODE[initialLanguage])
  const [language, setLanguage] = useState<LabCodeLanguage>(initialLanguage)
  const [isAuthExpired, setIsAuthExpired] = useState(false)
  const [verifyError, setVerifyError] = useState<string | null>(null)
  const [lastRun, setLastRun] = useState<LabRunResult | null>(null)
  const [selectedTaskId, setSelectedTaskId] = useState<string | null>(initialTaskId)
  const [isVerifying, startVerify] = useTransition()

  const savedCodes = useRef<Record<string, string>>({})
  const currentTaskIdRef = useRef<string | null>(null)
  const languageRef = useRef<LabCodeLanguage>(initialLanguage)

  function changeLanguage(lang: LabCodeLanguage) {
    if (isLanguageLocked) return
    languageRef.current = lang
    setLanguage(lang)
    setCode(STARTER_CODE[lang])
    savedCodes.current = {}
  }

  // Memoized: passed into effect dependency arrays by consumers (e.g. the
  // course-notes lab bridge) — a fresh identity every render would fire
  // those effects on every render regardless of real state changes.
  const selectTask = useCallback(
    (taskId: string) => {
      if (currentTaskIdRef.current !== null) {
        savedCodes.current[currentTaskIdRef.current] = code
      }
      currentTaskIdRef.current = taskId
      setSelectedTaskId(taskId)
      setCode(savedCodes.current[taskId] ?? STARTER_CODE[languageRef.current])
      setVerifyError(null)
      setLastRun(null)
    },
    [code],
  )

  const verify = useCallback((taskId: string) => {
    setVerifyError(null)
    startVerify(async () => {
      const res = await verifyLabTaskAction(sessionId, taskId, code)
      if (!res.ok || !res.data) {
        const msg = res.error ?? "Verification failed. Please try again."
        if (isAuthError(msg)) {
          setIsAuthExpired(true)
          return
        }
        setVerifyError(msg)
        return
      }
      const data = res.data
      setLastRun({ passed: data.passed, stdout: data.stdout, stderr: data.stderr })
      if (data.passed) {
        const msg = data.score_added > 0 ? `Task passed! +${data.score_added} pts` : "Task passed!"
        toast.success(msg)
        setScore((s) => s + data.score_added)
        setCompletions((prev) => {
          const updated: TaskCompletion = {
            task_id: taskId,
            status: "passed",
            attempts: data.attempts,
            hints_used: prev.find((c) => c.task_id === taskId)?.hints_used ?? 0,
          }
          return prev.some((c) => c.task_id === taskId)
            ? prev.map((c) => (c.task_id === taskId ? updated : c))
            : [...prev, updated]
        })
      } else {
        setVerifyError("Not quite right — check your logic and try again.")
        setCompletions((prev) => {
          if (!prev.some((c) => c.task_id === taskId)) {
            return [
              ...prev,
              { task_id: taskId, status: "pending", attempts: data.attempts, hints_used: 0 },
            ]
          }
          return prev.map((c) =>
            c.task_id === taskId ? { ...c, attempts: data.attempts } : c,
          )
        })
      }
    })
  }, [sessionId, code])

  function resetState(newScore: number) {
    setCompletions([])
    setScore(newScore)
    setVerifyError(null)
    setLastRun(null)
    savedCodes.current = {}
    currentTaskIdRef.current = null
    setCode(STARTER_CODE[languageRef.current])
  }

  return {
    completions,
    score,
    code,
    setCode,
    language,
    changeLanguage,
    isLanguageLocked,
    selectTask,
    selectedTaskId,
    setSelectedTaskId,
    isVerifying,
    verify,
    verifyError,
    dismissVerifyError: () => setVerifyError(null),
    lastRun,
    isAuthExpired,
    resetState,
  }
}
