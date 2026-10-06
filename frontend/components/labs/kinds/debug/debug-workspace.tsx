"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import { DebugFinishBar } from "@/components/labs/kinds/debug/debug-finish-bar"
import { DebugCheckBar } from "@/components/labs/kinds/debug/debug-check-bar"
import { DebugFailureList } from "@/components/labs/kinds/debug/debug-failure-list"
import { DebugMain } from "@/components/labs/kinds/debug/debug-main"
import { DebugTicketPanel } from "@/components/labs/kinds/debug/debug-ticket-panel"
import { DebugWriteupPanel } from "@/components/labs/kinds/debug/debug-writeup-panel"
import type { LabKindWorkspaceProps } from "@/components/labs/kinds/workspace-registry"
import { HintDrawer } from "@/components/labs/hint-drawer"
import { LabTaskChecklist } from "@/components/labs/lab-task-checklist"
import { SessionExpiredOverlay } from "@/components/labs/session-expired-overlay"
import { useDebugCheck } from "@/hooks/use-debug-check"
import { useLabHint } from "@/hooks/use-lab-hint"
import { useWriteupReview } from "@/hooks/use-writeup-review"
import ROUTES from "@/lib/routes"

/**
 * Workspace of the "debug" lab kind: ticket + checks + write-up on the left,
 * browser IDE / running app on the right (stacked on mobile). A server-side
 * reset bumps resetNonce, which remounts this body so all state restarts.
 */
export function DebugWorkspace(props: LabKindWorkspaceProps) {
  return <DebugWorkspaceBody key={props.resetNonce} {...props} />
}

function DebugWorkspaceBody({
  session,
  lab,
  initialCompletions,
  kindBlock,
  resetNonce,
  onScoreChange,
  onAuthExpiredChange,
  onLogin,
}: LabKindWorkspaceProps) {
  const router = useRouter()
  const [isAuthExpired, setIsAuthExpired] = useState(false)
  const isFresh = resetNonce > 0

  const expireAuth = () => {
    setIsAuthExpired(true)
    onAuthExpiredChange?.(true)
  }
  const goToResult = () => router.push(ROUTES.labSessionResult(session.id))
  // The deadline hit while a request was in flight: a completed lab is a
  // success (debrief), an expired one still lands on its result page.
  const onDeadline = (outcome: "completed" | "expired") => {
    toast(
      outcome === "completed"
        ? "Time's up — your lab was completed."
        : "Time's up — this lab session expired.",
    )
    goToResult()
  }
  const check = useDebugCheck({
    sessionId: session.id,
    tasks: lab.tasks,
    initialCompletions: isFresh ? [] : initialCompletions,
    initialScore: isFresh ? 0 : session.score,
    onScoreChange,
    onAuthExpired: expireAuth,
    onSessionCompleted: goToResult,
    onDeadline,
  })
  const writeup = useWriteupReview((result) => {
    if (result.passed) check.applyWriteupPass(result.score_added)
    if (result.session_completed) goToResult()
  }, onDeadline)
  const hint = useLabHint(session.id, check.completions, onDeadline)

  const maxScore = lab.tasks.reduce((sum, t) => sum + t.points, 0)
  const hintsUsedByTask = Object.fromEntries(
    lab.tasks.map((t) => [t.task_id, hint.hintsUsedFor(t.task_id)]),
  )

  return (
    <div className="relative flex min-h-0 flex-1 flex-col overflow-y-auto md:flex-row md:overflow-hidden">
      {isAuthExpired && <SessionExpiredOverlay onLogin={onLogin} />}

      <aside className="flex w-full shrink-0 flex-col gap-4 border-b border-border p-4 md:w-96 md:overflow-y-auto md:border-b-0 md:border-r">
        <DebugTicketPanel brief={kindBlock.brief} title={lab.title} />
        <div className="flex flex-col gap-3">
          <LabTaskChecklist
            completions={check.completions}
            hintsUsedByTask={hintsUsedByTask}
            isVerifying={check.isChecking}
            maxHints={hint.maxHints}
            maxScore={maxScore}
            renderTaskDetail={(task) => (
              <DebugFailureList failures={check.failures[task.task_id] ?? []} />
            )}
            score={check.score}
            scrollable={false}
            selectedTaskId={null}
            showTaskCheck={false}
            tasks={lab.tasks}
            onCheck={check.check}
            onHint={hint.openDrawer}
            onTaskSelect={() => undefined}
          />
          <DebugCheckBar
            cooldownUntil={check.cooldownUntil}
            isChecking={check.isChecking}
            message={check.message}
            problem={check.problem}
            onCheck={check.check}
          />
          <DebugFinishBar
            enabled={check.requiredPassed}
            sessionId={session.id}
            onAuthExpired={expireAuth}
          />
        </div>
        <DebugWriteupPanel
          error={writeup.error}
          isReviewing={writeup.isReviewing}
          remaining={writeup.remaining}
          result={writeup.result}
          onSubmit={() => writeup.submit(session.id)}
        />
      </aside>

      <div className="h-dvh min-h-0 w-full md:h-auto md:flex-1">
        <DebugMain
          appPorts={kindBlock.app_ports}
          idePort={kindBlock.ide_port}
          sessionId={session.id}
        />
      </div>

      <HintDrawer
        error={hint.error}
        hintPenaltyPct={lab.hint_penalty_pct}
        hintsUsed={hint.openTaskId ? hint.hintsUsedFor(hint.openTaskId) : 0}
        isRequesting={hint.isRequesting}
        maxHints={hint.maxHints}
        open={hint.openTaskId !== null}
        revealedHints={hint.openTaskId ? (hint.hintsByTask[hint.openTaskId] ?? []) : []}
        task={lab.tasks.find((t) => t.task_id === hint.openTaskId)}
        onOpenChange={(open) => {
          if (!open) hint.closeDrawer()
        }}
        onRequestHint={() => hint.openTaskId && hint.requestHint(hint.openTaskId)}
      />
    </div>
  )
}
