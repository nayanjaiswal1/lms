import type { CSSProperties } from "react"
import { CheckCircle2, Circle, Lightbulb } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { DebugFailureList } from "@/components/labs/kinds/debug/debug-failure-list"
import { cn } from "@/lib/utils"
import type { CheckFailure } from "@/lib/labs/kinds/debug-results"
import type { LabTask, TaskCompletion } from "@/lib/labs"

interface DebugTaskListProps {
  tasks: LabTask[]
  completions: TaskCompletion[]
  failures: Record<string, CheckFailure[]>
  hintsUsedByTask: Record<string, number>
  maxHints: number
  onHint: (taskId: string) => void
}

/** Compact checks list: one flat row per task, failures from the last Check inline. */
export function DebugTaskList({
  tasks,
  completions,
  failures,
  hintsUsedByTask,
  maxHints,
  onHint,
}: DebugTaskListProps) {
  const passed = new Set(completions.filter((c) => c.status === "passed").map((c) => c.task_id))
  const percent = tasks.length === 0 ? 0 : Math.round((passed.size / tasks.length) * 100)

  return (
    <section aria-label="Checks" className="flex flex-col gap-4">
      <div className="flex flex-col gap-1.5">
        <div className="flex-between text-xs text-muted-foreground">
          <span>
            {passed.size} of {tasks.length} checks passed
          </span>
          <span className="tabular-nums">{percent}%</span>
        </div>
        <div aria-hidden className="progress-track">
          <div className="progress-fill" style={{ "--progress": `${percent}%` } as CSSProperties} />
        </div>
      </div>

      <ol className="flex flex-col divide-y divide-border">
        {tasks.map((task) => {
          const isPassed = passed.has(task.task_id)
          const used = hintsUsedByTask[task.task_id] ?? 0
          return (
            <li className="flex items-start gap-3 py-3 first:pt-0 last:pb-0" key={task.task_id}>
              {isPassed ? (
                <CheckCircle2 aria-label="Passed" className="mt-0.5 h-4 w-4 shrink-0 text-success" />
              ) : (
                <Circle aria-label="Pending" className="mt-0.5 h-4 w-4 shrink-0 text-muted-foreground" />
              )}
              <div className="flex min-w-0 flex-1 flex-col gap-1">
                <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
                  <span className={cn("text-sm font-medium", isPassed && "text-muted-foreground")}>
                    {task.title}
                  </span>
                  {task.is_optional && (
                    <Badge className="text-xs" variant="outline">
                      optional
                    </Badge>
                  )}
                  {task.points > 0 && (
                    <span className="text-xs tabular-nums text-muted-foreground">{task.points} pts</span>
                  )}
                </div>
                {!isPassed && (
                  <>
                    <p className="text-xs text-muted-foreground">{task.description}</p>
                    <DebugFailureList failures={failures[task.task_id] ?? []} />
                  </>
                )}
              </div>
              {isPassed && used > 0 && (
                <span
                  aria-label={`${used} of ${maxHints} hints used on ${task.title}`}
                  className="flex shrink-0 items-center gap-1 text-xs tabular-nums text-muted-foreground"
                >
                  <Lightbulb aria-hidden className="h-3.5 w-3.5" />
                  {used}/{maxHints}
                </span>
              )}
              {!isPassed && task.grader !== "writeup_review" && (
                <Button
                  aria-label={`Get a hint for ${task.title} (${used} of ${maxHints} used)`}
                  className="touch-target-dense -my-2 shrink-0 gap-1 px-2 text-ai hover:text-ai"
                  disabled={used >= maxHints}
                  size="sm"
                  variant="ghost"
                  onClick={() => onHint(task.task_id)}
                >
                  <Lightbulb aria-hidden className="h-3.5 w-3.5" />
                  <span className="text-xs tabular-nums">
                    {used}/{maxHints}
                  </span>
                </Button>
              )}
            </li>
          )
        })}
      </ol>
    </section>
  )
}
