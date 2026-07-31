"use client"

import { createContext, useContext, useEffect, useState, useTransition, type ReactNode } from "react"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import { startLabSessionAction, endLabSessionAction } from "@/app/(app)/labs/[labId]/actions"
import { isLabAuthError, type LabVerifyBridge } from "@/components/labs/lab-workspace-content"
import { useLabProvisioning } from "@/lib/labs/provisioning-context"
import { isLabSessionAlreadyEnded, type GetSessionResponse, type Lab } from "@/lib/labs"
import ROUTES from "@/lib/routes"

interface LessonLabContextValue {
  lab: Lab
  initialSession: GetSessionResponse | null
  verifyBridge: LabVerifyBridge | null
  setVerifyBridge: (bridge: LabVerifyBridge) => void
  isStarting: boolean
  isEnding: boolean
  isOtherLabActive: boolean
  handleStart: () => void
  handleEnd: () => void
}

const LessonLabContext = createContext<LessonLabContextValue | null>(null)

export function useLessonLab(): LessonLabContextValue {
  const ctx = useContext(LessonLabContext)
  if (!ctx) throw new Error("useLessonLab must be used within LessonLabProvider")
  return ctx
}

interface LessonLabProviderProps {
  lab: Lab
  initialSession: GetSessionResponse | null
  children: ReactNode
}

// Mirrors ModuleLabClient's start/end flow (same actions, same
// router.refresh()-driven provisioning->running transition) but exposes
// state via context instead of owning the render, since the lesson body
// needs to render a hero *and* scattered per-task cards around it.
//
// verifyBridge is *not* a second useLabVerify instance — LabWorkspaceContent
// (rendered by LessonLabHero) owns the one true instance and reports it up
// here via onVerifyStateChange, so the terminal's own Check button and the
// inline task cards always agree.
export function LessonLabProvider({ lab, initialSession, children }: LessonLabProviderProps) {
  const router = useRouter()
  const { session: activeSession, track, clear, registerCurrentPageLab, unregisterCurrentPageLab } = useLabProvisioning()
  const [isStarting, startStarting] = useTransition()
  const [isEnding, startEnding] = useTransition()
  const [verifyBridge, setVerifyBridge] = useState<LabVerifyBridge | null>(null)

  // Tells LabProvisioningWatcher "this page's own inline UI covers lab.id" —
  // otherwise it can't distinguish that from "I'm on some *other* course
  // learn page that happens to embed a different lab," and would wrongly
  // suppress its toast for a session provisioning elsewhere. See that
  // component's isInlineHosted for the read side.
  useEffect(() => {
    registerCurrentPageLab(lab.id)
    return () => unregisterCurrentPageLab(lab.id)
  }, [lab.id, registerCurrentPageLab, unregisterCurrentPageLab])

  const isOtherLabActive = activeSession !== null && activeSession.lab_id !== lab.id

  const handleStart = () => {
    if (isOtherLabActive) {
      toast.error(`${activeSession.lab_title} is still running`, {
        description: "End it to start this lab instead — you can only run one lab at a time.",
      })
      return
    }

    startStarting(async () => {
      const result = await startLabSessionAction(lab.id, crypto.randomUUID())
      if (result.error || !result.data) {
        toast.error(result.error ?? "Failed to start lab session.")
        return
      }
      track({
        session_id: result.data.id,
        lab_id: lab.id,
        lab_title: lab.title,
        lab_type: lab.lab_type,
        status: result.data.status,
        started_at: result.data.started_at,
        expires_at: result.data.expires_at,
        last_active_at: result.data.last_active_at,
      })
      router.refresh()
    })
  }

  const handleEnd = () => {
    if (!initialSession) return
    const sessionId = initialSession.session.id
    startEnding(async () => {
      const res = await endLabSessionAction(sessionId)
      if (!res.ok && !isLabSessionAlreadyEnded(res.error ?? "")) {
        const msg = res.error ?? "Failed to end lab. Please try again."
        if (isLabAuthError(msg)) {
          router.push(ROUTES.LOGIN)
          return
        }
        toast.error(msg)
        return
      }
      clear(sessionId)
      router.refresh()
    })
  }

  return (
    <LessonLabContext.Provider
      value={{
        lab,
        initialSession,
        verifyBridge,
        setVerifyBridge,
        isStarting,
        isEnding,
        isOtherLabActive,
        handleStart,
        handleEnd,
      }}
    >
      {children}
    </LessonLabContext.Provider>
  )
}
