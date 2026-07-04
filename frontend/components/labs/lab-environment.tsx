"use client"

import { useState, useTransition } from "react"
import dynamic from "next/dynamic"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import {
  MonitorOff,
  RotateCcw,
  LogOut,
  Trophy,
  LogIn,
  Columns2,
  Rows2,
  AlertCircle,
  X,
} from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
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
import {
  ResizablePanelGroup,
  ResizablePanel,
  ResizableHandle,
} from "@/components/ui/resizable"
import { LabTimer } from "@/components/labs/lab-timer"
import { LabTaskPanel } from "@/components/labs/lab-task-panel"
import { LabContainerWorkspace } from "@/components/labs/lab-container-workspace"
import { endLabSessionAction, resetLabSessionAction } from "@/app/(app)/labs/[labId]/actions"
import { useLabVerify } from "@/hooks/use-lab-verify"
import { useLabNavigationGuard } from "@/hooks/use-lab-navigation-guard"
import ROUTES from "@/lib/routes"
import { isLabSessionAlreadyEnded, type Lab, type LabSession, type TaskCompletion } from "@/lib/labs"

const LabCodePanel = dynamic(
  () => import("@/components/labs/lab-code-panel").then((m) => m.LabCodePanel),
  { ssr: false, loading: () => <Skeleton className="h-full w-full rounded-none" /> },
)

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

function SessionExpiredOverlay({ onLogin }: { onLogin: () => void }) {
  return (
    <div
      aria-live="assertive"
      className="absolute inset-0 z-modal flex flex-col items-center justify-center gap-4 bg-background/95 backdrop-blur-sm px-6"
      role="alert"
    >
      <div className="flex flex-col items-center gap-3 text-center max-w-xs">
        <div className="rounded-full bg-muted p-4">
          <LogIn aria-hidden className="h-6 w-6 text-muted-foreground" />
        </div>
        <div className="flex flex-col gap-1.5">
          <p className="font-semibold text-foreground">Session expired</p>
          <p className="text-sm text-muted-foreground">
            Your login session has expired. Please log in again to continue — your progress is
            saved.
          </p>
        </div>
        <Button className="w-full" onClick={onLogin}>
          Log in again
        </Button>
      </div>
    </div>
  )
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

export function LabEnvironment({ session, lab, initialCompletions }: LabEnvironmentProps) {
  const defaultTaskId =
    lab.tasks.find((t) => {
      const c = initialCompletions.find((c) => c.task_id === t.task_id)
      return !c || c.status === "pending"
    })?.task_id ?? lab.tasks[0]?.task_id ?? null

  const {
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
    dismissVerifyError,
    lastRun,
    isAuthExpired,
    resetState,
  } = useLabVerify(session.id, initialCompletions, session.score, lab.language, defaultTaskId)

  const [resetCount, setResetCount] = useState(session.reset_count)
  const [layoutOrientation, setLayoutOrientation] = useState<"horizontal" | "vertical">(
    "horizontal",
  )
  const [isPending, startTransition] = useTransition()
  const [isResetting, startReset] = useTransition()
  const router = useRouter()

  const maxScore = lab.tasks.reduce((s, t) => s + t.points, 0)
  const isCodeLab = lab.lab_type === "code"
  const handleTaskSelect = isCodeLab ? selectTask : setSelectedTaskId
  const isTaskPassed =
    completions.find((c) => c.task_id === selectedTaskId)?.status === "passed"

  // Clearing LabProvisioningContext happens on the result page itself
  // (ClearActiveLabSession), not here — that page is the one guaranteed
  // destination for every path off a terminal session (manual end, discovered
  // auto-expiry, stale resume), so it's the single place that needs to know.
  const endAndGoToResult = async () => {
    const res = await endLabSessionAction(session.id)
    if (!res.ok && !isLabSessionAlreadyEnded(res.error ?? "")) {
      const msg = res.error ?? "Failed to end lab. Please try again."
      if (isAuthError(msg)) {
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
        if (isAuthError(msg)) {
          router.push(ROUTES.LOGIN)
          return
        }
        return
      }
      setResetCount(res.data.session.reset_count)
      resetState(0)
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

      {verifyError && (
        <div
          className="flex items-center gap-2 border-b border-destructive/30 bg-destructive/10 px-4 py-2 shrink-0"
          role="alert"
        >
          <AlertCircle aria-hidden className="h-4 w-4 text-destructive shrink-0" />
          <p className="text-sm text-destructive flex-1 min-w-0">{verifyError}</p>
          <button
            aria-label="Dismiss error"
            className="text-destructive hover:text-destructive/80 shrink-0 touch-target"
            type="button"
            onClick={dismissVerifyError}
          >
            <X aria-hidden className="h-3.5 w-3.5" />
          </button>
        </div>
      )}

      {/* Mobile layout */}
      <div className="relative flex flex-col flex-1 md:hidden overflow-auto">
        {isAuthExpired && <SessionExpiredOverlay onLogin={handleLogin} />}
        <div className="flex items-center gap-2 px-4 py-3 bg-muted/50 border-b border-border">
          <MonitorOff aria-hidden className="h-4 w-4 text-muted-foreground shrink-0" />
          <p className="text-sm text-muted-foreground">
            {isCodeLab
              ? "The code editor requires a larger screen. Viewing tasks only."
              : "The terminal requires a larger screen. Viewing tasks only."}
          </p>
        </div>
        <LabTaskPanel
          completions={completions}
          maxScore={maxScore}
          score={score}
          selectedTaskId={selectedTaskId}
          tasks={lab.tasks}
          onTaskSelect={handleTaskSelect}
        />
      </div>

      {/* Desktop layout */}
      <div className="relative hidden md:flex flex-1 overflow-hidden">
        {isAuthExpired && <SessionExpiredOverlay onLogin={handleLogin} />}
        <ResizablePanelGroup orientation={layoutOrientation}>
          <ResizablePanel
            className={
              layoutOrientation === "horizontal"
                ? "border-r border-border"
                : "border-b border-border"
            }
            defaultSize="24%"
            id="lab-tasks"
            maxSize="45%"
            minSize="18%"
          >
            <LabTaskPanel
              completions={completions}
              maxScore={maxScore}
              score={score}
              selectedTaskId={selectedTaskId}
              tasks={lab.tasks}
              onTaskSelect={handleTaskSelect}
            />
          </ResizablePanel>
          <ResizableHandle withHandle orientation={layoutOrientation} />
          <ResizablePanel defaultSize="76%" id="lab-workspace" minSize="40%">
            {isCodeLab ? (
              <LabCodePanel
                code={code}
                isLanguageLocked={isLanguageLocked}
                isTaskPassed={isTaskPassed}
                isVerifying={isVerifying}
                language={language}
                lastRun={lastRun}
                taskId={selectedTaskId ?? undefined}
                onCheck={verify}
                onCodeChange={setCode}
                onLanguageChange={changeLanguage}
              />
            ) : (
              <LabContainerWorkspace
                isTaskPassed={isTaskPassed}
                isVerifying={isVerifying}
                sessionId={session.id}
                taskId={selectedTaskId ?? undefined}
                onCheck={verify}
              />
            )}
          </ResizablePanel>
        </ResizablePanelGroup>
      </div>
    </div>
  )
}
