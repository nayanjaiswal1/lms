"use client"

import { useState, useTransition } from "react"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import { RotateCcw, LogOut, Trophy, Columns2, Rows2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  AlertDialog,
  AlertDialogTrigger,
  AlertDialogContent,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogCancel,
  AlertDialogAction,
} from "@/components/ui/alert-dialog"
import { LabTimer } from "@/components/labs/lab-timer"
import {
  LabWorkspaceContent,
  isLabAuthError,
} from "@/components/labs/lab-workspace-content"
import { endLabSessionAction, resetLabSessionAction } from "@/app/(app)/labs/[labId]/actions"
import { useLabNavigationGuard } from "@/hooks/use-lab-navigation-guard"
import ROUTES from "@/lib/routes"
import { isLabSessionAlreadyEnded, type Lab, type LabSession, type TaskCompletion } from "@/lib/labs"

interface LabEnvironmentProps {
  session: LabSession
  lab: Lab
  initialCompletions: TaskCompletion[]
}

interface TopBarProps {
  labTitle: string
  labType: string
  maxResets: number
  expiresAt: string
  score: number
  maxScore: number
  resetCount: number
  isPending: boolean
  isResetting: boolean
  layoutOrientation: "horizontal" | "vertical"
  onEnd: () => void
  onExpired: () => void
  onReset: () => void
  onToggleLayout: () => void
}

function LabEnvironmentTopBar({
  labTitle,
  labType,
  maxResets,
  expiresAt,
  score,
  maxScore,
  resetCount,
  isPending,
  isResetting,
  layoutOrientation,
  onEnd,
  onExpired,
  onReset,
  onToggleLayout,
}: TopBarProps) {
  const resetsLeft = maxResets - resetCount
  const canReset = resetsLeft > 0

  return (
    <header className="h-14 shrink-0 flex items-center justify-between gap-3 px-4 border-b border-border bg-card">
      <div className="flex items-center gap-2 min-w-0">
        <span className="font-semibold text-sm truncate text-foreground">{labTitle}</span>
        <Badge className="capitalize shrink-0 hidden sm:inline-flex text-xs" variant="outline">
          {labType}
        </Badge>
      </div>

      <div className="shrink-0">
        <LabTimer expiresAt={expiresAt} onExpired={onExpired} />
      </div>

      <div className="flex items-center gap-2 shrink-0">
        {maxScore > 0 && (
          <div
            aria-label={`Score: ${score} of ${maxScore} points`}
            className="hidden sm:flex items-center gap-1 text-xs tabular-nums text-muted-foreground"
          >
            <Trophy aria-hidden className="h-3.5 w-3.5 text-primary shrink-0" />
            <span>
              {score}/{maxScore}
            </span>
          </div>
        )}

        <Button
          aria-label={
            layoutOrientation === "horizontal"
              ? "Switch to stacked layout"
              : "Switch to side-by-side layout"
          }
          className="gap-1.5 text-muted-foreground hover:text-foreground hidden md:inline-flex"
          size="sm"
          variant="ghost"
          onClick={onToggleLayout}
        >
          {layoutOrientation === "horizontal" ? (
            <Rows2 aria-hidden className="h-3.5 w-3.5" />
          ) : (
            <Columns2 aria-hidden className="h-3.5 w-3.5" />
          )}
        </Button>

        {canReset && (
          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button
                aria-label={`Reset lab — ${resetsLeft} reset${resetsLeft !== 1 ? "s" : ""} remaining`}
                className="gap-1.5 text-muted-foreground hover:text-foreground hidden sm:inline-flex"
                disabled={isPending || isResetting}
                size="sm"
                variant="ghost"
              >
                <RotateCcw aria-hidden className="h-3.5 w-3.5" />
                <span className="hidden md:inline">Reset</span>
                <Badge className="text-xs py-0 px-1.5 shrink-0" variant="secondary">
                  {resetsLeft}
                </Badge>
              </Button>
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>Reset this lab?</AlertDialogTitle>
                <AlertDialogDescription>
                  All task completions and your score will be cleared. Your code in the editor will
                  also reset. This uses one of your {resetsLeft} remaining reset
                  {resetsLeft !== 1 ? "s" : ""} — this action cannot be undone.
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>Cancel</AlertDialogCancel>
                <AlertDialogAction
                  className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                  onClick={onReset}
                >
                  {isResetting ? "Resetting…" : "Reset Lab"}
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        )}

        <Button
          aria-label="End lab session"
          className="gap-1.5"
          disabled={isPending || isResetting}
          size="sm"
          variant="outline"
          onClick={onEnd}
        >
          <LogOut aria-hidden className="h-3.5 w-3.5" />
          <span className="hidden sm:inline">{isPending ? "Ending…" : "End Lab"}</span>
        </Button>
      </div>
    </header>
  )
}

export function LabEnvironment({ session, lab, initialCompletions }: LabEnvironmentProps) {
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
    if (!res.ok && !isLabSessionAlreadyEnded(res.error ?? "")) {
      const msg = res.error ?? "Failed to end lab. Please try again."
      if (isLabAuthError(msg)) {
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
        if (isLabAuthError(msg)) {
          router.push(ROUTES.LOGIN)
          return
        }
        return
      }
      setResetCount(res.data.session.reset_count)
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
