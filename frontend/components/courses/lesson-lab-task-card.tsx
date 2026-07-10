"use client"

import { CheckCircle2, Loader2 } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { useLessonLab } from "@/components/courses/lesson-lab-provider"

interface LessonLabTaskCardProps {
  position: number
}

// Google Cloud Skills Boost style "Check my progress" card, placed inline at
// a task's own point in the lesson via the [[lab-task:N]] marker. Reads the
// same verify state LabWorkspaceContent's terminal Check button reads, via
// LessonLabProvider's bridge — there's only one source of truth.
export function LessonLabTaskCard({ position }: LessonLabTaskCardProps) {
  const { lab, initialSession, verifyBridge } = useLessonLab()
  const task = lab.tasks.find((t) => t.position === position)
  if (!task) return null

  const isRunning =
    initialSession?.session.status === "running" || initialSession?.session.status === "paused"
  const status = verifyBridge?.completions.find((c) => c.task_id === task.task_id)?.status ?? "pending"
  const isPassed = status === "passed"
  const isChecking = verifyBridge?.isVerifying && verifyBridge.selectedTaskId === task.task_id

  return (
    <div className="card-base flex items-start gap-3 p-4">
      <span
        className={
          isPassed
            ? "flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-success/20 text-success"
            : "flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-muted text-xs font-semibold text-muted-foreground"
        }
      >
        {isPassed ? <CheckCircle2 aria-hidden className="h-4 w-4" /> : position}
      </span>
      <div className="flex min-w-0 flex-1 flex-col gap-1">
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-sm font-medium">{task.title}</span>
          {task.points > 0 && (
            <Badge className="text-xs" variant="secondary">{task.points} pts</Badge>
          )}
        </div>
        <p className="text-xs text-muted-foreground">{task.description}</p>
        {!isRunning && (
          <p className="text-xs text-muted-foreground">Start the lab above first.</p>
        )}
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
            disabled={!verifyBridge || verifyBridge.isVerifying}
            size="sm"
            variant="outline"
            onClick={() => verifyBridge?.checkTask(task.task_id)}
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
    </div>
  )
}
