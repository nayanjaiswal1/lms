"use client"

import { useState } from "react"
import { CheckCircle2, SkipForward, Circle, Loader2, CheckCircle, AlertCircle } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { ScrollArea } from "@/components/ui/scroll-area"
import { cn } from "@/lib/utils"
import type { LabTask, TaskCompletion, TaskStatus } from "@/lib/labs"

interface LabTaskPanelProps {
  tasks: LabTask[]
  completions: TaskCompletion[]
  score: number
  maxScore: number
  onCheck?: (taskId: string) => void
  onTaskSelect?: (taskId: string) => void
  isVerifying?: boolean
  verifyError?: string | null
}

interface LabTaskRowProps {
  task: LabTask
  completion: TaskCompletion | undefined
  isSelected: boolean
  onSelect: () => void
}

function LabTaskRow({ task, completion, isSelected, onSelect }: LabTaskRowProps) {
  const status: TaskStatus = completion?.status ?? "pending"
  const attempts = completion?.attempts ?? 0

  return (
    <button
      type="button"
      onClick={onSelect}
      className={cn(
        "w-full flex items-start gap-3 px-4 py-3 text-left transition-colors duration-fast",
        "hover:bg-muted/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-inset",
        isSelected
          ? "bg-muted border-l-2 border-primary"
          : "border-l-2 border-transparent",
      )}
      aria-current={isSelected ? "true" : undefined}
    >
      <span className="mt-0.5 shrink-0">
        {status === "passed" ? (
          <CheckCircle2 aria-label="Passed" className="h-4 w-4 text-success" />
        ) : status === "skipped" ? (
          <SkipForward aria-label="Skipped" className="h-4 w-4 text-muted-foreground" />
        ) : (
          <Circle aria-label="Pending" className="h-4 w-4 text-muted-foreground/60" />
        )}
      </span>
      <div className="flex flex-col gap-0.5 min-w-0 flex-1">
        <div className="flex items-center gap-1.5 flex-wrap">
          <span
            className={cn(
              "text-sm font-medium leading-snug",
              status === "passed"
                ? "text-muted-foreground line-through"
                : isSelected
                ? "text-foreground"
                : "text-foreground/80",
            )}
          >
            {task.position}. {task.title}
          </span>
          {task.is_optional && (
            <Badge variant="outline" className="text-xs shrink-0 py-0">
              optional
            </Badge>
          )}
        </div>
        {attempts > 0 && (
          <span className="text-xs text-muted-foreground">
            {attempts} attempt{attempts !== 1 ? "s" : ""}
          </span>
        )}
      </div>
      {task.points > 0 && (
        <span
          className={cn(
            "shrink-0 text-xs tabular-nums",
            status === "passed" ? "text-success" : "text-muted-foreground",
          )}
        >
          {task.points} pts
        </span>
      )}
    </button>
  )
}

export function LabTaskPanel({
  tasks,
  completions,
  score,
  maxScore,
  onCheck,
  onTaskSelect,
  isVerifying = false,
  verifyError,
}: LabTaskPanelProps) {
  const [selectedTaskId, setSelectedTaskId] = useState<string | null>(
    tasks.find((t) => {
      const c = completions.find((c) => c.task_id === t.task_id)
      return !c || c.status === "pending"
    })?.task_id ?? tasks[0]?.task_id ?? null,
  )

  const completionMap = new Map(completions.map((c) => [c.task_id, c]))
  const selectedTask = tasks.find((t) => t.task_id === selectedTaskId)
  const selectedCompletion = selectedTaskId ? completionMap.get(selectedTaskId) : undefined
  const alreadyPassed = selectedCompletion?.status === "passed"
  const canCheck = Boolean(onCheck) && !alreadyPassed && !isVerifying

  const passedCount = completions.filter((c) => c.status === "passed").length

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
          <Badge
            variant={score > 0 ? "default" : "secondary"}
            className="tabular-nums shrink-0"
          >
            {score} / {maxScore} pts
          </Badge>
        )}
      </div>

      <ScrollArea className="flex-1">
        <div className="flex flex-col py-1">
          {tasks.map((task) => (
            <LabTaskRow
              key={task.task_id}
              task={task}
              completion={completionMap.get(task.task_id)}
              isSelected={task.task_id === selectedTaskId}
              onSelect={() => {
                setSelectedTaskId(task.task_id)
                onTaskSelect?.(task.task_id)
              }}
            />
          ))}
        </div>
      </ScrollArea>

      {selectedTask && (
        <div className="border-t border-border shrink-0">
          <div className="p-4 flex flex-col gap-3">
            <div className="flex flex-col gap-1.5">
              <div className="flex items-start justify-between gap-2">
                <p className="text-xs font-semibold text-foreground leading-snug">
                  {selectedTask.position}. {selectedTask.title}
                </p>
                {selectedTask.points > 0 && (
                  <span className="text-xs text-muted-foreground tabular-nums shrink-0">
                    {selectedTask.points} pts
                  </span>
                )}
              </div>
              <p className="text-xs text-muted-foreground leading-relaxed">
                {selectedTask.description}
              </p>
            </div>

            {onCheck ? (
              <div className="flex flex-col gap-1.5">
                <Button
                  size="sm"
                  variant={alreadyPassed ? "secondary" : "default"}
                  className={cn(
                    "w-full gap-1.5",
                    alreadyPassed && "text-success",
                  )}
                  disabled={!canCheck}
                  onClick={() => onCheck(selectedTask.task_id)}
                  aria-label={
                    alreadyPassed ? "Task already passed" : isVerifying ? "Verifying…" : "Check task"
                  }
                >
                  {isVerifying ? (
                    <>
                      <Loader2 className="h-3.5 w-3.5 animate-spin" aria-hidden />
                      Checking…
                    </>
                  ) : alreadyPassed ? (
                    <>
                      <CheckCircle className="h-3.5 w-3.5" aria-hidden />
                      Passed
                    </>
                  ) : (
                    "Check"
                  )}
                </Button>
                {verifyError && !alreadyPassed && (
                  <div
                    role="alert"
                    className="flex items-start gap-1.5 rounded-md border border-destructive/30 bg-destructive/10 px-2.5 py-2"
                  >
                    <AlertCircle aria-hidden className="h-3.5 w-3.5 text-destructive shrink-0 mt-0.5" />
                    <p className="text-xs text-destructive leading-snug">{verifyError}</p>
                  </div>
                )}
              </div>
            ) : null}
          </div>
        </div>
      )}
    </div>
  )
}
