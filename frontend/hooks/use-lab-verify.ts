"use client"

import { useState, useTransition, useRef } from "react"
import { toast } from "sonner"
import { verifyLabTaskAction } from "@/app/(app)/labs/[labId]/actions"
import type { TaskCompletion, LabCodeLanguage } from "@/lib/labs"

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
) {
  const [completions, setCompletions] = useState<TaskCompletion[]>(initialCompletions)
  const [score, setScore] = useState(initialScore)
  const [code, setCode] = useState(STARTER_CODE.javascript)
  const [language, setLanguage] = useState<LabCodeLanguage>("javascript")
  const [verifyError, setVerifyError] = useState<string | null>(null)
  const [isAuthExpired, setIsAuthExpired] = useState(false)
  const [isVerifying, startVerify] = useTransition()

  const savedCodes = useRef<Record<string, string>>({})
  const currentTaskIdRef = useRef<string | null>(null)
  const languageRef = useRef<LabCodeLanguage>("javascript")

  function changeLanguage(lang: LabCodeLanguage) {
    languageRef.current = lang
    setLanguage(lang)
    setCode(STARTER_CODE[lang])
    savedCodes.current = {}
  }

  function selectTask(taskId: string) {
    if (currentTaskIdRef.current !== null) {
      savedCodes.current[currentTaskIdRef.current] = code
    }
    currentTaskIdRef.current = taskId
    setCode(savedCodes.current[taskId] ?? STARTER_CODE[languageRef.current])
    setVerifyError(null)
  }

  function verify(taskId: string) {
    setVerifyError(null)
    startVerify(async () => {
      const res = await verifyLabTaskAction(sessionId, taskId, code, language)
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
      if (data.passed) {
        const msg = data.score_added > 0 ? `Task passed! +${data.score_added} pts` : "Task passed!"
        toast.success(msg)
        setVerifyError(null)
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
  }

  function resetState(newScore: number) {
    setCompletions([])
    setScore(newScore)
    setVerifyError(null)
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
    selectTask,
    isVerifying,
    verify,
    verifyError,
    isAuthExpired,
    resetState,
  }
}
