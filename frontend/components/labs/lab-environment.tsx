"use client"

import { useState, useTransition } from "react"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import {
  AlertDialog,
  AlertDialogContent,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogCancel,
  AlertDialogAction,
} from "@/components/ui/alert-dialog"
import { LabEnvironmentTopBar } from "@/components/labs/lab-environment-top-bar"
import {
  LabWorkspaceContent,
  isLabAuthError,
} from "@/components/labs/lab-workspace-content"
import { endLabSessionAction, resetLabSessionAction } from "@/app/(app)/labs/[labId]/actions"
import { useLabNavigationGuard } from "@/hooks/use-lab-navigation-guard"
import ROUTES from "@/lib/routes"
import {
  isLabSessionAlreadyEnded,
  type Lab,
  type LabKindBlock,
  type LabSession,
  type TaskCompletion,
} from "@/lib/labs"

interface LabEnvironmentProps {
  session: LabSession
  lab: Lab
  initialCompletions: TaskCompletion[]
  kindBlock?: LabKindBlock
}

export function LabEnvironment({ session, lab, initialCompletions, kindBlock }: LabEnvironmentProps) {
  const [score, setScore] = useState(session.score)
  const [isAuthExpired, setIsAuthExpired] = useState(false)
  const [resetCount, setResetCount] = useState(session.reset_count)
  const [resetNonce, setResetNonce] = useState(0)
  const [layoutOrientation, setLayoutOrientation] = useState<"horizontal" | "vertical">(
    "horizontal",
  )
  const [isPending, startTransition] = useTransition()
  const [isResetting, startReset] = useTransition()
  const router = useRouter()

  const maxScore = lab.tasks.reduce((s, t) => s + t.points, 0)

  // Clearing LabProvisioningContext happens on the result page itself
  // (ClearActiveLabSession), not here — that page is the one guaranteed
  // destination for every path off a terminal session (manual end, discovered
  // auto-expiry, stale resume), so it's the single place that needs to know.
  const endAndGoToResult = async () => {
    const res = await endLabSessionAction(session.id)
    if (!res.ok && !isLabSessionAlreadyEnded(res.code)) {
      const msg = res.error ?? "Failed to end lab. Please try again."
      if (isLabAuthError(res)) {
        router.push(ROUTES.LOGIN)
        return
      }
      toast.error(msg)
      return
    }
    router.push(ROUTES.labSessionResult(session.id))
  }

  const handleEnd = () => {
    startTransition(endAndGoToResult)
  }

  const handleExpired = () => {
    startTransition(endAndGoToResult)
  }

  const handleReset = () => {
    startReset(async () => {
      const res = await resetLabSessionAction(session.id)
      if (!res.ok || !res.data) {
        const msg = res.error ?? "Failed to reset lab. Please try again."
        if (isLabAuthError(res)) {
          router.push(ROUTES.LOGIN)
          return
        }
        toast.error(msg)
        return
      }
      setResetCount(res.data.session.reset_count)
      setScore(0)
      setResetNonce((n) => n + 1)
    })
  }

  const handleLogin = () => {
    router.push(ROUTES.LOGIN)
  }

  const { showLeaveConfirm, confirmLeave, cancelLeave } = useLabNavigationGuard({
    enabled: !isAuthExpired,
    onConfirmLeave: handleEnd,
  })

  return (
    <div className="fixed inset-0 bg-background z-modal flex flex-col safe-inset">
      <AlertDialog open={showLeaveConfirm} onOpenChange={(open) => !open && cancelLeave()}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Leave this lab session?</AlertDialogTitle>
            <AlertDialogDescription>
              Going back will end your lab session now. Your progress so far is saved, but the
              environment will be torn down. This action cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel onClick={cancelLeave}>Stay in lab</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={confirmLeave}
            >
              End & Leave
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <LabEnvironmentTopBar
        expiresAt={session.expires_at}
        isPending={isPending}
        isResetting={isResetting}
        labTitle={lab.title}
        labType={lab.lab_type}
        layoutOrientation={layoutOrientation}
        maxResets={lab.max_resets}
        maxScore={maxScore}
        resetCount={resetCount}
        score={score}
        onEnd={handleEnd}
        onExpired={handleExpired}
        onReset={handleReset}
        onToggleLayout={() =>
          setLayoutOrientation((o) => (o === "horizontal" ? "vertical" : "horizontal"))
        }
      />

      <LabWorkspaceContent
        initialCompletions={initialCompletions}
        kindBlock={kindBlock}
        lab={lab}
        orientation={layoutOrientation}
        resetNonce={resetNonce}
        session={session}
        onAuthExpiredChange={setIsAuthExpired}
        onLogin={handleLogin}
        onScoreChange={setScore}
      />
    </div>
  )
}
