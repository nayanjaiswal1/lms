"use client"

import { useState, useTransition } from "react"
import { PanelRight } from "lucide-react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Sheet, SheetContent, SheetDescription, SheetTitle } from "@/components/ui/sheet"
import { startMissionAction } from "@/app/(app)/labs/[labId]/actions"
import { DebugCheckBar } from "@/components/labs/kinds/debug/debug-check-bar"
import { DebugCheckNotice } from "@/components/labs/kinds/debug/debug-check-notice"
import { DebugMain } from "@/components/labs/kinds/debug/debug-main"
import { MissionBanner } from "@/components/labs/kinds/debug/mission/mission-banner"
import { MissionBriefing } from "@/components/labs/kinds/debug/mission/mission-briefing"
import { MissionHeader } from "@/components/labs/kinds/debug/mission/mission-header"
import { MissionRail } from "@/components/labs/kinds/debug/mission/mission-rail"
import { MissionShipButton } from "@/components/labs/kinds/debug/mission/mission-ship-button"
import type { LabKindWorkspaceProps } from "@/components/labs/kinds/workspace-registry"
import { HintDrawer } from "@/components/labs/hint-drawer"
import { LabResetButton } from "@/components/labs/lab-reset-button"
import { SessionExpiredOverlay } from "@/components/labs/session-expired-overlay"
import { useDebugSession } from "@/hooks/use-debug-session"
import { useFinishLab } from "@/hooks/use-finish-lab"
import { useMissionActivity } from "@/hooks/use-mission-activity"
import { useMissionClock } from "@/hooks/use-mission-clock"
import { isLabAuthError } from "@/lib/labs/auth-error"
import { isLabSessionExpired } from "@/lib/labs"

interface MissionClockState {
  started: boolean
  expiresAt: string
}

/**
 * Workspace of the "debug" lab kind for orgs on the new UI: a briefing the
 * student starts (the server-side clock runs from Start), a slim mission bar,
 * the IDE / live preview full width and a dense rail. The clock state lives
 * here, above the reset remount, so a reset never re-shows the briefing.
 */
export function MissionWorkspace(props: LabKindWorkspaceProps) {
  const [clock, setClock] = useState<MissionClockState>({
    started: Boolean(props.session.mission_started_at),
    expiresAt: props.session.expires_at,
  })
  return <MissionWorkspaceBody clock={clock} key={props.resetNonce} onStarted={setClock} {...props} />
}

interface MissionWorkspaceBodyProps extends LabKindWorkspaceProps {
  clock: MissionClockState
  onStarted: (clock: MissionClockState) => void
}

function MissionWorkspaceBody(props: MissionWorkspaceBodyProps) {
  const { session, lab, kindBlock, clock, onStarted, onLogin, onReset, resetsLeft = 0, isResetting = false } = props
  const debug = useDebugSession(props)
  const { check, hint, isAuthExpired, expireAuth, goToResult } = debug
  const [railOpen, setRailOpen] = useState(false)
  const [isStarting, startStarting] = useTransition()
  const finish = useFinishLab(session.id, expireAuth)

  // Ship and the deadline both do the same thing: a final Check, then end the session.
  async function submitFinal() {
    await check.check()
    finish.finish()
  }
  const { secondsLeft, phase } = useMissionClock({
    expiresAt: clock.expiresAt,
    active: clock.started,
    onAutoSubmit: () => void submitFinal(),
  })
  useMissionActivity(session.id, clock.started)

  function start() {
    startStarting(async () => {
      const res = await startMissionAction(session.id)
      if (isLabSessionExpired(res.code)) {
        goToResult()
        return
      }
      if (!res.ok || !res.data) {
        if (isLabAuthError(res)) expireAuth()
        else toast.error(res.error ?? "Could not start the mission. Please try again.")
        return
      }
      onStarted({ started: true, expiresAt: res.data.session.expires_at })
    })
  }

  const budgetSeconds = (Date.parse(session.expires_at) - Date.parse(session.started_at)) / 1000
  const autoSubmitting = phase === "ending" || phase === "expired"
  const rail = (className?: string) => (
    <MissionRail brief={kindBlock.brief} className={className} debug={debug} lab={lab} sessionId={session.id} />
  )

  return (
    <div className="relative flex min-h-0 flex-1 flex-col">
      {isAuthExpired && <SessionExpiredOverlay onLogin={onLogin} />}

      <MissionHeader
        actions={
          clock.started ? (
            <>
              <DebugCheckBar
                cooldownUntil={check.cooldownUntil}
                isChecking={check.isChecking}
                variant="outline"
                onCheck={check.check}
              />
              <MissionShipButton
                isBusy={check.isChecking || finish.isFinishing}
                isGrading={finish.isFinishing || (autoSubmitting && check.isChecking)}
                passed={debug.passedCount}
                total={lab.tasks.length}
                onShip={() => void submitFinal()}
              />
              {onReset && (
                <LabResetButton
                  busy={finish.isFinishing}
                  isResetting={isResetting}
                  resetsLeft={resetsLeft}
                  onReset={onReset}
                />
              )}
              <Button
                aria-label="Open mission panel"
                className="touch-target-dense lg:hidden"
                size="icon"
                variant="ghost"
                onClick={() => setRailOpen(true)}
              >
                <PanelRight aria-hidden />
              </Button>
            </>
          ) : null
        }
        secondsLeft={clock.started ? secondsLeft : null}
        title={lab.title}
      />
      <MissionBanner phase={phase} />
      <DebugCheckNotice message={check.message} problem={check.problem} onRetry={check.check} />

      {clock.started ? (
        <div className="flex min-h-0 flex-1">
          <div className="min-w-0 flex-1">
            <DebugMain
              appPorts={kindBlock.app_ports}
              idePort={kindBlock.ide_port}
              labId={session.lab_id}
              sessionId={session.id}
              variant="mission"
            />
          </div>
          {rail("hidden w-80 shrink-0 border-l border-border lg:flex xl:w-96")}
        </div>
      ) : (
        <div className="min-h-0 flex-1 bg-muted/30" />
      )}

      <Sheet open={railOpen} onOpenChange={setRailOpen}>
        <SheetContent className="gap-0 p-0 lg:hidden">
          <SheetTitle className="sr-only">Mission panel</SheetTitle>
          <SheetDescription className="sr-only">Alert, checks, live status and write-up.</SheetDescription>
          {rail("pt-10")}
        </SheetContent>
      </Sheet>

      {!clock.started && (
        <MissionBriefing
          brief={kindBlock.brief}
          budgetSeconds={budgetSeconds}
          isStarting={isStarting}
          lab={lab}
          onStart={start}
        />
      )}

      {clock.started && (
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
      )}
    </div>
  )
}
