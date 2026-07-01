"use client"

import { useState, useTransition } from "react"
import dynamic from "next/dynamic"
import { useRouter } from "next/navigation"
import { MonitorOff, RotateCcw, LogOut, Trophy, LogIn } from "lucide-react"
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
import { LabTimer } from "@/components/labs/lab-timer"
import { LabTaskPanel } from "@/components/labs/lab-task-panel"
import { endLabSessionAction, resetLabSessionAction } from "@/app/(app)/labs/[labId]/actions"
import { useLabVerify } from "@/hooks/use-lab-verify"
import ROUTES from "@/lib/routes"
import type { Lab, LabSession, TaskCompletion } from "@/lib/labs"

const LabTerminal = dynamic(
  () => import("@/components/labs/lab-terminal").then((m) => m.LabTerminal),
  { ssr: false, loading: () => <Skeleton className="h-full w-full rounded-none" /> },
)

const LabCodePanel = dynamic(
  () => import("@/components/labs/lab-code-panel").then((m) => m.LabCodePanel),
  { ssr: false, loading: () => <Skeleton className="h-full w-full rounded-none" /> },
)

interface LabEnvironmentProps {
  session: LabSession
  lab: Lab
  wsToken: string
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
  onEnd: () => void
  onExpired: () => void
  onReset: () => void
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
  onEnd,
  onExpired,
  onReset,
}: TopBarProps) {
  const resetsLeft = maxResets - resetCount
  const canReset = resetsLeft > 0

  return (
    <header className="h-14 shrink-0 flex items-center justify-between gap-3 px-4 border-b border-border bg-card">
      <div className="flex items-center gap-2 min-w-0">
        <span className="font-semibold text-sm truncate text-foreground">{labTitle}</span>
        <Badge variant="outline" className="capitalize shrink-0 hidden sm:inline-flex text-xs">
          {labType}
        </Badge>
      </div>

      <div className="shrink-0">
        <LabTimer expiresAt={expiresAt} onExpired={onExpired} />
      </div>

      <div className="flex items-center gap-2 shrink-0">
        {maxScore > 0 && (
          <div
            className="hidden sm:flex items-center gap-1 text-xs tabular-nums text-muted-foreground"
            aria-label={`Score: ${score} of ${maxScore} points`}
          >
            <Trophy aria-hidden className="h-3.5 w-3.5 text-primary shrink-0" />
            <span>
              {score}/{maxScore}
            </span>
          </div>
        )}

        {canReset && (
          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button
                variant="ghost"
                size="sm"
                className="gap-1.5 text-muted-foreground hover:text-foreground hidden sm:inline-flex"
                disabled={isPending || isResetting}
                aria-label={`Reset lab — ${resetsLeft} reset${resetsLeft !== 1 ? "s" : ""} remaining`}
              >
                <RotateCcw aria-hidden className="h-3.5 w-3.5" />
                <span className="hidden md:inline">Reset</span>
                <Badge variant="secondary" className="text-xs py-0 px-1.5 shrink-0">
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
                  onClick={onReset}
                  className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                >
                  {isResetting ? "Resetting…" : "Reset Lab"}
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        )}

        <Button
          variant="outline"
          size="sm"
          onClick={onEnd}
          disabled={isPending || isResetting}
          aria-label="End lab session"
          className="gap-1.5"
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
      role="alert"
      aria-live="assertive"
      className="absolute inset-0 z-modal flex flex-col items-center justify-center gap-4 bg-background/95 backdrop-blur-sm px-6"
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
        <Button onClick={onLogin} className="w-full">
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

export function LabEnvironment({ session, lab, wsToken, initialCompletions }: LabEnvironmentProps) {
  const {
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
  } = useLabVerify(session.id, initialCompletions, session.score)

  const [resetCount, setResetCount] = useState(session.reset_count)
  const [isPending, startTransition] = useTransition()
  const [isResetting, startReset] = useTransition()
  const router = useRouter()

  const maxScore = lab.tasks.reduce((s, t) => s + t.points, 0)
  const isCodeLab = lab.lab_type === "code"

  const handleEnd = () => {
    startTransition(async () => {
      await endLabSessionAction(session.id)
      router.push(ROUTES.labSessionResult(session.id))
    })
  }

  const handleExpired = () => {
    startTransition(async () => {
      await endLabSessionAction(session.id)
      router.push(ROUTES.labSessionResult(session.id))
    })
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

  return (
    <div className="fixed inset-0 bg-background z-modal flex flex-col safe-inset">
      <LabEnvironmentTopBar
        labTitle={lab.title}
        labType={lab.lab_type}
        maxResets={lab.max_resets}
        expiresAt={session.expires_at}
        score={score}
        maxScore={maxScore}
        resetCount={resetCount}
        isPending={isPending}
        isResetting={isResetting}
        onEnd={handleEnd}
        onExpired={handleExpired}
        onReset={handleReset}
      />

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
          tasks={lab.tasks}
          completions={completions}
          score={score}
          maxScore={maxScore}
        />
      </div>

      {/* Desktop layout */}
      <div className="relative hidden md:flex flex-1 overflow-hidden">
        {isAuthExpired && <SessionExpiredOverlay onLogin={handleLogin} />}
        <aside className="w-80 shrink-0 border-r border-border overflow-hidden flex flex-col">
          <LabTaskPanel
            tasks={lab.tasks}
            completions={completions}
            score={score}
            maxScore={maxScore}
            onCheck={isCodeLab ? verify : undefined}
            onTaskSelect={isCodeLab ? selectTask : undefined}
            isVerifying={isVerifying}
            verifyError={verifyError}
          />
        </aside>
        <div className="flex-1 overflow-hidden">
          {isCodeLab ? (
            <LabCodePanel
              code={code}
              language={language}
              onCodeChange={setCode}
              onLanguageChange={changeLanguage}
            />
          ) : (
            <LabTerminal sessionId={session.id} wsToken={wsToken} />
          )}
        </div>
      </div>
    </div>
  )
}
