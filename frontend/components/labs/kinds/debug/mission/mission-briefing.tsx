"use client"

import { Loader2 } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog"
import { LabMarkdown } from "@/components/labs/kinds/debug/lab-markdown"
import { ACTIVITY_DISCLOSURE, formatMissionClock } from "@/lib/labs/kinds/debug-mission"
import { parseTicketMeta } from "@/lib/labs/kinds/debug-ticket"
import type { Lab } from "@/lib/labs"

interface MissionBriefingProps {
  lab: Lab
  brief: string
  /** The full time budget the clock counts down from once Start is pressed. */
  budgetSeconds: number
  isStarting: boolean
  onStart: () => void
}

/**
 * Blocking briefing shown before the clock starts. It cannot be dismissed: the
 * only way into the workspace is Start, which starts the server-side clock.
 */
export function MissionBriefing({ lab, brief, budgetSeconds, isStarting, onStart }: MissionBriefingProps) {
  const { severity, reporter, body } = parseTicketMeta(brief)
  const required = lab.tasks.filter((t) => !t.is_optional)

  return (
    <Dialog open>
      <DialogContent
        className="flex max-h-[90dvh] max-w-2xl flex-col gap-0 overflow-hidden p-0"
        showClose={false}
        onEscapeKeyDown={(e) => e.preventDefault()}
        onInteractOutside={(e) => e.preventDefault()}
      >
        <header className="flex flex-col gap-2 border-b border-border p-4">
          <div className="flex items-center gap-2">
            <Badge variant="default">Mission</Badge>
            <Badge variant="outline">Debug lab</Badge>
            {severity && <Badge variant="destructive">{severity}</Badge>}
            <span className="ml-auto font-mono text-xs text-muted-foreground">
              budget {formatMissionClock(budgetSeconds)}
            </span>
          </div>
          <DialogTitle className="text-lg font-semibold leading-snug">{lab.title}</DialogTitle>
          <DialogDescription className="sr-only">
            Mission briefing. Press Start mission to begin the timed attempt.
          </DialogDescription>
        </header>

        <div className="flex min-h-0 flex-1 flex-col gap-3 overflow-y-auto p-4">
          <section aria-label="Incident" className="rounded-lg border border-destructive/40 bg-destructive/5 p-3">
            {reporter && (
              <p className="mb-1 font-mono text-xs uppercase tracking-wider text-destructive">
                Reported by {reporter}
              </p>
            )}
            <LabMarkdown>{body}</LabMarkdown>
          </section>

          {lab.description && (
            <section aria-label="Objective" className="flex flex-col gap-1">
              <h2 className="font-mono text-xs uppercase tracking-wider text-muted-foreground">Objective</h2>
              <p className="text-sm font-medium leading-6">{lab.description}</p>
            </section>
          )}

          {required.length > 0 && (
            <section aria-label="What you will be graded on" className="flex flex-col gap-1">
              <h2 className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                What to find
              </h2>
              <ul className="list-disc space-y-1 pl-5 text-sm leading-6">
                {required.map((task) => (
                  <li key={task.task_id}>{task.title}</li>
                ))}
              </ul>
            </section>
          )}
        </div>

        <footer className="flex flex-col gap-3 border-t border-border p-4 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-xs leading-5 text-muted-foreground">{ACTIVITY_DISCLOSURE}</p>
          <Button className="shrink-0 gap-2" disabled={isStarting} onClick={onStart}>
            {isStarting && <Loader2 aria-hidden className="h-4 w-4 animate-spin" />}
            Start mission
          </Button>
        </footer>
      </DialogContent>
    </Dialog>
  )
}
