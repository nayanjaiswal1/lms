"use client"

import { useState } from "react"
import { ChevronDown } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Collapsible, CollapsibleContent } from "@/components/ui/collapsible"
import { DebugTaskList } from "@/components/labs/kinds/debug/debug-task-list"
import { DebugWriteupPanel } from "@/components/labs/kinds/debug/debug-writeup-panel"
import { LabMarkdown } from "@/components/labs/kinds/debug/lab-markdown"
import { MissionCard } from "@/components/labs/kinds/debug/mission/mission-card"
import { MissionLiveStatus } from "@/components/labs/kinds/debug/mission/mission-live-status"
import type { useDebugSession } from "@/hooks/use-debug-session"
import { RESTART_COMMAND, RESTART_NOTE, parseTicketMeta } from "@/lib/labs/kinds/debug-ticket"
import { cn } from "@/lib/utils"
import type { Lab } from "@/lib/labs"

interface MissionRailProps {
  lab: Lab
  brief: string
  sessionId: string
  debug: ReturnType<typeof useDebugSession>
  className?: string
}

/**
 * Right rail of the mission workspace, replacing the classic Ticket / Checks /
 * Write-up tabs with one scroll of dense cards: the alert, the mission and its
 * checks, live status, and the write-up (collapsed until needed).
 */
export function MissionRail({ lab, brief, sessionId, debug, className }: MissionRailProps) {
  const [writeupOpen, setWriteupOpen] = useState(false)
  const { check, hint, writeup, passedCount, hintsUsedByTask } = debug
  const { severity, reporter, body } = parseTicketMeta(brief)
  const maxScore = lab.tasks.reduce((sum, t) => sum + t.points, 0)

  return (
    <div className={cn("flex min-h-0 flex-col gap-2 overflow-y-auto overflow-x-hidden bg-background p-2", className)}>
      <MissionCard
        aside={
          <span className="flex items-center gap-1.5">
            {severity && <Badge variant="destructive">{severity}</Badge>}
            {reporter && <span className="truncate text-xs text-muted-foreground">{reporter}</span>}
          </span>
        }
        label="Alert"
        tone="alert"
      >
        <div className="max-h-56 overflow-y-auto">
          <LabMarkdown>{body}</LabMarkdown>
        </div>
      </MissionCard>

      <MissionCard label="Mission">
        <h3 className="text-sm font-semibold leading-snug">{lab.title}</h3>
        {lab.description && <p className="text-xs leading-5 text-muted-foreground">{lab.description}</p>}
        <DebugTaskList
          dense
          completions={check.completions}
          failures={check.failures}
          hintsUsedByTask={hintsUsedByTask}
          maxHints={hint.maxHints}
          tasks={lab.tasks}
          onHint={hint.openDrawer}
        />
        <p className="border-t border-border pt-2 text-xs text-muted-foreground">
          {RESTART_NOTE} <code>{RESTART_COMMAND}</code>.
        </p>
      </MissionCard>

      <MissionLiveStatus
        completions={check.completions}
        maxScore={maxScore}
        passed={passedCount}
        resolved={check.requiredPassed}
        score={check.score}
        total={lab.tasks.length}
      />

      <MissionCard
        aside={
          <Button
            aria-expanded={writeupOpen}
            aria-label="Toggle write-up"
            className="touch-target-dense -my-1.5"
            size="icon"
            variant="ghost"
            onClick={() => setWriteupOpen((open) => !open)}
          >
            <ChevronDown aria-hidden className={cn("transition-transform", writeupOpen && "rotate-180")} />
          </Button>
        }
        label="Write-up"
      >
        <Collapsible open={writeupOpen}>
          <CollapsibleContent>
            <DebugWriteupPanel
              error={writeup.error}
              isReviewing={writeup.isReviewing}
              remaining={writeup.remaining}
              result={writeup.result}
              onSubmit={() => writeup.submit(sessionId)}
            />
          </CollapsibleContent>
        </Collapsible>
        {!writeupOpen && (
          <p className="text-xs text-muted-foreground">Root-cause write-up, reviewed against the rubric.</p>
        )}
      </MissionCard>
    </div>
  )
}
