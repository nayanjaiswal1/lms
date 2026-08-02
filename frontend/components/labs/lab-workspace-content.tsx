"use client"

import { useEffect, useRef } from "react"
import dynamic from "next/dynamic"
import { MonitorOff, LogIn, AlertCircle, X } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { cn } from "@/lib/utils"
import {
  ResizablePanelGroup,
  ResizablePanel,
  ResizableHandle,
} from "@/components/ui/resizable"
import { LabTaskPanel } from "@/components/labs/lab-task-panel"
import { LabTaskChecklist } from "@/components/labs/lab-task-checklist"
import { LabContainerWorkspace } from "@/components/labs/lab-container-workspace"
import { SandboxWorkspace } from "@/components/labs/sandbox-workspace"
import { LabConsoleWorkspace } from "@/components/labs/lab-console-workspace"
import { LabFixedConsole } from "@/components/labs/lab-fixed-console"
import { useLabVerify } from "@/hooks/use-lab-verify"
import type { Lab, LabSession, TaskCompletion } from "@/lib/labs"

const LabCodePanel = dynamic(
  () => import("@/components/labs/lab-code-panel").then((m) => m.LabCodePanel),
  { ssr: false, loading: () => <Skeleton className="h-full w-full rounded-none" /> },
)

/** Shared auth-error sniffing for lab server-action failures. */
export function isLabAuthError(msg: string): boolean {
  const lower = msg.toLowerCase()
  return (
    lower.includes("invalid or expired") ||
    lower.includes("unauthorized") ||
    lower.includes("not authenticated") ||
    lower.includes("session expired")
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

/**
 * Live verify state reported upward for hosts that need it outside this
 * component's own checklist/workspace rendering — e.g. the course notes
 * embed, where "Check my progress" cards are scattered through the lesson
 * body instead of living in a single checklist. Sourced from this
 * component's own `useLabVerify` instance so there's exactly one source of
 * truth: the terminal's built-in Check button and the external cards drive
 * (and reflect) the same state.
 */
export interface LabVerifyBridge {
  completions: TaskCompletion[]
  isVerifying: boolean
  selectedTaskId: string | null
  /** Selects the task (so the workspace panel targets it too) and verifies it. */
  checkTask: (taskId: string) => void
}

interface LabWorkspaceContentProps {
  session: LabSession
  lab: Lab
  initialCompletions: TaskCompletion[]
  /** Split direction of the desktop task/workspace panels. */
  orientation?: "horizontal" | "vertical"
  /**
   * Increment to clear all verify state (completions, score, editor code)
   * after a successful server-side lab reset.
   */
  resetNonce?: number
  /**
   * How a "console" layout lab renders on desktop: "boxed" keeps the
   * checklist + terminal drawer confined to this component's own bounded
   * parent (the full-screen /labs/[labId] environment). "fixed" flows the
   * checklist inline with the rest of the page and pins the terminal to the
   * bottom of the browser viewport instead (the course notes embed).
   */
  consoleMode?: "boxed" | "fixed"
  /**
   * Skip rendering the built-in `<LabTaskChecklist>` in the fixed console
   * branch. Used by the course notes embed, which renders its own scattered
   * per-task cards instead — driven by `onVerifyStateChange` below rather
   * than a second checklist.
   */
  hideTaskChecklist?: boolean
  onVerifyStateChange?: (bridge: LabVerifyBridge) => void
  onScoreChange?: (score: number) => void
  onAuthExpiredChange?: (expired: boolean) => void
  onLogin: () => void
}

/**
 * The session-agnostic core of a running lab: task panel + code/container
 * workspace with verification wiring. Owns `useLabVerify`; hosts (the
 * full-screen `LabEnvironment`, or an inline course embed) provide their own
 * chrome (top bar, dialogs, navigation guards) around it. Must be rendered
 * inside a `flex flex-col` container.
 */
export function LabWorkspaceContent({
  session,
  lab,
  initialCompletions,
  orientation = "horizontal",
  resetNonce = 0,
  consoleMode = "boxed",
  hideTaskChecklist = false,
  onVerifyStateChange,
  onScoreChange,
  onAuthExpiredChange,
  onLogin,
}: LabWorkspaceContentProps) {
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

  useEffect(() => {
    onScoreChange?.(score)
  }, [score, onScoreChange])

  useEffect(() => {
    onAuthExpiredChange?.(isAuthExpired)
  }, [isAuthExpired, onAuthExpiredChange])

  const prevNonce = useRef(resetNonce)
  useEffect(() => {
    if (resetNonce !== prevNonce.current) {
      prevNonce.current = resetNonce
      resetState(0)
    }
  }, [resetNonce, resetState])

  const maxScore = lab.tasks.reduce((s, t) => s + t.points, 0)
  const isCodeLab = lab.lab_type === "code"
  const handleTaskSelect = isCodeLab ? selectTask : setSelectedTaskId
  const isTaskPassed =
    completions.find((c) => c.task_id === selectedTaskId)?.status === "passed"

  useEffect(() => {
    onVerifyStateChange?.({
      completions,
      isVerifying,
      selectedTaskId,
      checkTask: (taskId: string) => {
        handleTaskSelect(taskId)
        verify(taskId)
      },
    })
  }, [completions, isVerifying, selectedTaskId, onVerifyStateChange, handleTaskSelect, verify])

  // Sandbox/playground labs get the CodeSandbox-style IDE instead of the
  // task-checklist layout — no per-task Check; grading (if the lab has tasks)
  // happens through the workspace's batch Submit. Early return is safe here:
  // every hook above has already run unconditionally.
  if (lab.lab_type === "sandbox" || lab.lab_type === "playground") {
    return (
      <div className="relative flex flex-col flex-1 min-h-0">
        {isAuthExpired && <SessionExpiredOverlay onLogin={onLogin} />}
        <SandboxWorkspace
          lab={lab}
          sessionId={session.id}
          onScoreChange={onScoreChange}
        />
      </div>
    )
  }

  const workspacePanel = isCodeLab ? (
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
      hasCluster={lab.has_cluster}
      isTaskPassed={isTaskPassed}
      isVerifying={isVerifying}
      previewPort={lab.preview_port}
      sessionId={session.id}
      taskId={selectedTaskId ?? undefined}
      onCheck={verify}
    />
  )

  return (
    <>
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
        {isAuthExpired && <SessionExpiredOverlay onLogin={onLogin} />}
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
      <div
        className={cn(
          "relative hidden md:flex flex-1",
          !(lab.layout === "console" && consoleMode === "fixed") && "overflow-hidden",
        )}
      >
        {isAuthExpired && <SessionExpiredOverlay onLogin={onLogin} />}
        {lab.layout === "console" ? (
          consoleMode === "fixed" ? (
            <div className="flex w-full flex-col gap-4">
              {!hideTaskChecklist && (
                <LabTaskChecklist
                  completions={completions}
                  isVerifying={isVerifying}
                  maxScore={maxScore}
                  score={score}
                  scrollable={false}
                  selectedTaskId={selectedTaskId}
                  tasks={lab.tasks}
                  onCheck={verify}
                  onTaskSelect={handleTaskSelect}
                />
              )}
              <LabFixedConsole title={isCodeLab ? "Editor" : "Console"}>
                {workspacePanel}
              </LabFixedConsole>
            </div>
          ) : (
            <LabConsoleWorkspace
              completions={completions}
              isVerifying={isVerifying}
              maxScore={maxScore}
              score={score}
              selectedTaskId={selectedTaskId}
              tasks={lab.tasks}
              workspacePanel={workspacePanel}
              onCheck={verify}
              onTaskSelect={handleTaskSelect}
            />
          )
        ) : (
          <ResizablePanelGroup orientation={orientation}>
            <ResizablePanel
              className={
                orientation === "horizontal"
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
            <ResizableHandle withHandle orientation={orientation} />
            <ResizablePanel defaultSize="76%" id="lab-workspace" minSize="40%">
              {workspacePanel}
            </ResizablePanel>
          </ResizablePanelGroup>
        )}
      </div>
    </>
  )
}
