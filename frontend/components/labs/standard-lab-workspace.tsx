"use client"

import { Button } from "@/components/ui/button";

import { useEffect, useRef } from "react"
import dynamic from "next/dynamic"
import { MonitorOff, AlertCircle, X } from "lucide-react"
import { Skeleton } from "@/components/ui/skeleton"
import { SessionExpiredOverlay } from "@/components/labs/session-expired-overlay"
import { IconMessage } from "@/components/shared/icon-message"
import { LabTaskPanel } from "@/components/labs/lab-task-panel"
import { LabContainerWorkspace } from "@/components/labs/lab-container-workspace"
import { SandboxWorkspace } from "@/components/labs/sandbox-workspace"
import { StandardLabDesktopLayout } from "@/components/labs/standard-lab-desktop-layout"
import { HintDrawer } from "@/components/labs/hint-drawer"
import { useLabVerify } from "@/hooks/use-lab-verify"
import { useLabHint } from "@/hooks/use-lab-hint"
import type {
  LabVerifyBridge,
  LabWorkspaceContentProps,
} from "@/components/labs/standard-lab-workspace-types"

const LabCodePanel = dynamic(
  () => import("@/components/labs/lab-code-panel").then((m) => m.LabCodePanel),
  { ssr: false, loading: () => <Skeleton className="h-full w-full rounded-none" /> },
)

/**
 * The session-agnostic core of a running lab: task panel + code/container
 * workspace with verification wiring. Owns `useLabVerify`; hosts (the
 * full-screen `LabEnvironment`, or an inline course embed) provide their own
 * chrome (top bar, dialogs, navigation guards) around it. Must be rendered
 * inside a `flex flex-col` container.
 */
export type { LabVerifyBridge, LabWorkspaceContentProps }

export function StandardLabWorkspace({
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

  const {
    openTaskId: hintTaskId,
    openDrawer: openHintDrawer,
    closeDrawer: closeHintDrawer,
    hintsByTask,
    hintsUsedFor,
    requestHint,
    isRequesting: isRequestingHint,
    error: hintError,
    maxHints,
  } = useLabHint(session.id, completions)

  const hintsUsedByTask = Object.fromEntries(
    lab.tasks.map((t) => [t.task_id, hintsUsedFor(t.task_id)]),
  )

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
        <IconMessage
          action={
            <Button aria-label="Dismiss error"
              className="text-destructive hover:text-destructive/80 touch-target"
              type="button"
              variant="unstyled"
              onClick={dismissVerifyError}
            >
              <X aria-hidden className="h-3.5 w-3.5" />
            </Button>
          }
          className="shrink-0"
          icon={AlertCircle}
          role="alert"
          tone="destructive"
          variant="strip"
        >
          {verifyError}
        </IconMessage>
      )}

      {/* Mobile layout */}
      <div className="relative flex flex-col flex-1 md:hidden overflow-auto">
        {isAuthExpired && <SessionExpiredOverlay onLogin={onLogin} />}
        <IconMessage className="bg-muted/50" icon={MonitorOff} variant="strip">
          {isCodeLab
            ? "The code editor requires a larger screen. Viewing tasks only."
            : "The terminal requires a larger screen. Viewing tasks only."}
        </IconMessage>
        <LabTaskPanel
          completions={completions}
          hintsUsedByTask={hintsUsedByTask}
          maxHints={maxHints}
          maxScore={maxScore}
          score={score}
          selectedTaskId={selectedTaskId}
          tasks={lab.tasks}
          onHint={openHintDrawer}
          onTaskSelect={handleTaskSelect}
        />
      </div>

      <StandardLabDesktopLayout
        completions={completions}
        consoleMode={consoleMode}
        hideTaskChecklist={hideTaskChecklist}
        hintsUsedByTask={hintsUsedByTask}
        isAuthExpired={isAuthExpired}
        isCodeLab={isCodeLab}
        isVerifying={isVerifying}
        lab={lab}
        maxHints={maxHints}
        maxScore={maxScore}
        orientation={orientation}
        score={score}
        selectedTaskId={selectedTaskId}
        workspacePanel={workspacePanel}
        onCheck={verify}
        onHint={openHintDrawer}
        onLogin={onLogin}
        onTaskSelect={handleTaskSelect}
      />

      <HintDrawer
        error={hintError}
        hintPenaltyPct={lab.hint_penalty_pct}
        hintsUsed={hintTaskId ? hintsUsedFor(hintTaskId) : 0}
        isRequesting={isRequestingHint}
        maxHints={maxHints}
        open={hintTaskId !== null}
        revealedHints={hintTaskId ? hintsByTask[hintTaskId] ?? [] : []}
        task={lab.tasks.find((t) => t.task_id === hintTaskId)}
        onOpenChange={(open) => {
          if (!open) closeHintDrawer()
        }}
        onRequestHint={() => hintTaskId && requestHint(hintTaskId)}
      />
    </>
  )
}
