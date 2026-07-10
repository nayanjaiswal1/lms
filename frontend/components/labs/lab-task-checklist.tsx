"use client"

import { CheckCircle2, Loader2 } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { ScrollArea } from "@/components/ui/scroll-area"
import { cn } from "@/lib/utils"
import type { LabTask, TaskCompletion } from "@/lib/labs"

interface LabTaskChecklistProps {
  tasks: LabTask[]
  completions: TaskCompletion[]
  score: number
  maxScore: number
  selectedTaskId: string | null
  isVerifying: boolean
  onTaskSelect: (taskId: string) => void
  onCheck: (taskId: string) => void
  /** Bound the list in a ScrollArea filling its parent (default — for use
   *  inside a fixed-height box). Pass false to render as plain flow content
   *  that scrolls with the page instead (the course notes embed). */
  scrollable?: boolean
}

// Google Cloud Skills Boost style checklist: every task is visible at once
// with its own "Check my progress" action.
export function LabTaskChecklist({
  tasks,
  completions,
  score,
  maxScore,
  selectedTaskId,
  isVerifying,
  onTaskSelect,
  onCheck,
  scrollable = true,
}: LabTaskChecklistProps) {
  const completionMap = new Map(completions.map((c) => [c.task_id, c]))
  const passedCount = completions.filter((c) => c.status === "passed").length

  function handleCheck(taskId: string) {
    onTaskSelect(taskId)
    onCheck(taskId)
  }

  const list = (
    <ol className="flex flex-col gap-2 p-4">
      {tasks.map((task) => {
        const status = completionMap.get(task.task_id)?.status ?? "pending"
        const isPassed = status === "passed"
        const isChecking = isVerifying && selectedTaskId === task.task_id

        return (
          <li
            className={cn(
              "card-base flex items-start gap-3 p-4 transition-colors duration-fast",
              isPassed && "border-success/40 bg-success/10",
            )}
            key={task.task_id}
          >
            <span
              className={cn(
                "flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs font-semibold tabular-nums",
                isPassed ? "bg-success/20 text-success" : "bg-muted text-muted-foreground",
              )}
            >
              {isPassed ? <CheckCircle2 aria-hidden className="h-4 w-4" /> : task.position}
            </span>
            <div className="flex min-w-0 flex-1 flex-col gap-1">
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-sm font-medium">{task.title}</span>
                {task.is_optional && (
                  <Badge className="text-xs" variant="outline">optional</Badge>
                )}
                {task.points > 0 && (
                  <Badge className="text-xs" variant="secondary">{task.points} pts</Badge>
                )}
              </div>
              <p className="text-xs text-muted-foreground">{task.description}</p>
            </div>
            <div className="shrink-0">
              {isPassed ? (
                <div className="flex h-9 items-center gap-1.5 rounded-md border border-success/20 bg-success/10 px-3">
                  <CheckCircle2 aria-hidden className="h-3.5 w-3.5 text-success shrink-0" />
                  <span className="text-xs font-medium text-success whitespace-nowrap">Passed</span>
                </div>
              ) : (
                <Button
                  aria-label={isChecking ? "Checking progress…" : "Check my progress"}
                  className="gap-1.5"
                  disabled={isVerifying}
                  size="sm"
                  variant="outline"
                  onClick={() => handleCheck(task.task_id)}
                >
                  {isChecking ? (
                    <>
                      <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />
                      Checking…
                    </>
                  ) : (
                    "Check my progress"
                  )}
                </Button>
              )}
            </div>
          </li>
        )
      })}
    </ol>
  )

  return (
    <div className={cn("flex flex-col", scrollable && "flex-1 min-h-0")}>
      <div className="flex items-center justify-between border-b border-border px-4 py-3 shrink-0">
        <div className="flex flex-col gap-0.5">
          <span className="text-sm font-semibold text-foreground">Progress checker</span>
          <span className="text-xs text-muted-foreground">
            {passedCount}/{tasks.length} complete
          </span>
        </div>
        {maxScore > 0 && (
          <Badge className="tabular-nums shrink-0" variant={score > 0 ? "default" : "secondary"}>
            {score} / {maxScore} pts
          </Badge>
        )}
      </div>
      {scrollable ? <ScrollArea className="flex-1 min-h-0">{list}</ScrollArea> : list}
    </div>
  )
}
