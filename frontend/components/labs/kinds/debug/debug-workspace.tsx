"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import { DebugCheckNotice } from "@/components/labs/kinds/debug/debug-check-notice"
import { DebugFinishBar } from "@/components/labs/kinds/debug/debug-finish-bar"
import { DebugCheckBar } from "@/components/labs/kinds/debug/debug-check-bar"
import { DebugShell } from "@/components/labs/kinds/debug/debug-shell"
import { DebugSidePanel } from "@/components/labs/kinds/debug/debug-side-panel"
import { DebugTaskList } from "@/components/labs/kinds/debug/debug-task-list"
import { DebugMain } from "@/components/labs/kinds/debug/debug-main"
import { DebugTicketPanel } from "@/components/labs/kinds/debug/debug-ticket-panel"
import { DebugWriteupPanel } from "@/components/labs/kinds/debug/debug-writeup-panel"
import type { LabKindWorkspaceProps } from "@/components/labs/kinds/workspace-registry"
import { HintDrawer } from "@/components/labs/hint-drawer"
import { SessionExpiredOverlay } from "@/components/labs/session-expired-overlay"
import { useDebugCheck } from "@/hooks/use-debug-check"
import { useLabHint } from "@/hooks/use-lab-hint"
import { useWriteupReview } from "@/hooks/use-writeup-review"
import ROUTES from "@/lib/routes"

/**
 * Workspace of the "debug" lab kind: ticket + checks + write-up in a collapsible
 * side panel, browser IDE / running app full width. A server-side
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

  const passedCount = check.completions.filter((c) => c.status === "passed").length
  const hintsUsedByTask = Object.fromEntries(
    lab.tasks.map((t) => [t.task_id, hint.hintsUsedFor(t.task_id)]),
  )

  return (
    <div className="relative flex min-h-0 flex-1 flex-col">
      {isAuthExpired && <SessionExpiredOverlay onLogin={onLogin} />}

      <DebugShell
        notice={<DebugCheckNotice message={check.message} problem={check.problem} />}
        panel={
          <DebugSidePanel
            checks={
              <DebugTaskList
                completions={check.completions}
                failures={check.failures}
                hintsUsedByTask={hintsUsedByTask}
                maxHints={hint.maxHints}
                tasks={lab.tasks}
                onHint={hint.openDrawer}
              />
            }
            passed={passedCount}
            ticket={<DebugTicketPanel brief={kindBlock.brief} title={lab.title} />}
            total={lab.tasks.length}
            writeup={
              <DebugWriteupPanel
                error={writeup.error}
                isReviewing={writeup.isReviewing}
                remaining={writeup.remaining}
                result={writeup.result}
                onSubmit={() => writeup.submit(session.id)}
              />
            }
          />
        }
      >
        {(panelToggle) => (
          <DebugMain
            appPorts={kindBlock.app_ports}
            idePort={kindBlock.ide_port}
            leading={panelToggle}
            sessionId={session.id}
            trailing={
              <>
                <DebugCheckBar
                  cooldownUntil={check.cooldownUntil}
                  isChecking={check.isChecking}
                  onCheck={check.check}
                />
                <DebugFinishBar
                  enabled={check.requiredPassed}
                  sessionId={session.id}
                  onAuthExpired={expireAuth}
                />
              </>
            }
          />
        )}
      </DebugShell>

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
