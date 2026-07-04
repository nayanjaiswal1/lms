"use client"

import { CheckCircle2, SkipForward } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { ScrollArea } from "@/components/ui/scroll-area"
import { cn } from "@/lib/utils"
import type { LabTask, TaskCompletion, TaskStatus } from "@/lib/labs"

interface LabTaskPanelProps {
  tasks: LabTask[]
  completions: TaskCompletion[]
  score: number
  maxScore: number
  selectedTaskId: string | null
  onTaskSelect: (taskId: string) => void
}

interface TaskPillProps {
  task: LabTask
  completion: TaskCompletion | undefined
  isSelected: boolean
  onSelect: () => void
}

function TaskPill({ task, completion, isSelected, onSelect }: TaskPillProps) {
  const status: TaskStatus = completion?.status ?? "pending"

  return (
    <button
      aria-current={isSelected ? "true" : undefined}
      aria-label={`Task ${task.position}: ${task.title}${status === "passed" ? " — passed" : status === "skipped" ? " — skipped" : ""}`}
      className={cn(
        "flex h-8 w-8 shrink-0 items-center justify-center rounded-full border text-xs font-semibold tabular-nums transition-colors duration-fast",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary",
        status === "passed"
          ? "border-success/40 bg-success/10 text-success"
          : isSelected
          ? "border-primary bg-primary text-primary-foreground"
          : "border-border text-muted-foreground hover:border-primary/50 hover:text-foreground",
      )}
      type="button"
      onClick={onSelect}
    >
      {status === "passed" ? (
        <CheckCircle2 aria-hidden className="h-4 w-4" />
      ) : status === "skipped" ? (
        <SkipForward aria-hidden className="h-3.5 w-3.5" />
      ) : (
        task.position
      )}
    </button>
  )
}

export function LabTaskPanel({
  tasks,
  completions,
  score,
  maxScore,
  selectedTaskId,
  onTaskSelect,
}: LabTaskPanelProps) {
  const completionMap = new Map(completions.map((c) => [c.task_id, c]))
  const passedCount = completions.filter((c) => c.status === "passed").length
  const selectedTask = tasks.find((t) => t.task_id === selectedTaskId)

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center justify-between border-b border-border px-4 py-3 shrink-0">
        <div className="flex flex-col gap-0.5">
          <span className="text-sm font-semibold text-foreground">Tasks</span>
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

      <div className="flex items-center gap-2 overflow-x-auto border-b border-border px-4 py-3 shrink-0">
        {tasks.map((task) => (
          <TaskPill
            completion={completionMap.get(task.task_id)}
            isSelected={task.task_id === selectedTaskId}
            key={task.task_id}
            task={task}
            onSelect={() => onTaskSelect(task.task_id)}
          />
        ))}
      </div>

      {selectedTask && (
        <ScrollArea className="flex-1">
          <div className="flex flex-col gap-2 px-4 py-4">
            <div className="flex items-center justify-between gap-2">
              <span className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                Task {selectedTask.position} of {tasks.length}
              </span>
              {selectedTask.points > 0 && (
                <span className="text-xs font-medium tabular-nums text-muted-foreground shrink-0">
                  {selectedTask.points} pts
                </span>
              )}
            </div>
            <p className="text-sm font-semibold text-foreground leading-snug flex items-center gap-1.5 flex-wrap">
              {selectedTask.title}
              {selectedTask.is_optional && (
                <Badge className="text-xs py-0" variant="outline">
                  optional
                </Badge>
              )}
            </p>
            <p className="text-sm text-muted-foreground leading-relaxed whitespace-pre-wrap">
              {selectedTask.description}
            </p>
          </div>
        </ScrollArea>
      )}
    </div>
  )
}
