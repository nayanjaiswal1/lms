import type { Metadata } from "next"
import Link from "next/link"
import { redirect } from "next/navigation"
import { CheckCircle2, XCircle, Clock, Trophy } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Breadcrumb } from "@/components/shared/breadcrumb"
import { LAB_KIND_DEBRIEFS } from "@/components/labs/kinds/debrief-registry"
import { ClearActiveLabSession } from "@/components/labs/clear-active-lab-session"
import { FeedbackPrompt } from "@/components/feedback/feedback-prompt"
import { apiGet } from "@/lib/server/api"
import { getMyFeedback } from "@/lib/server/feedback"
import ROUTES from "@/lib/routes"
import type { Lab, GetSessionResponse, TaskStatus } from "@/lib/labs"

export const metadata: Metadata = {
  title: "Lab Result",
  robots: { index: false, follow: false },
}

interface PageProps {
  params: Promise<{ sessionId: string }>
}

function formatDuration(startedAt: string, completedAt: string): string {
  const ms = new Date(completedAt).getTime() - new Date(startedAt).getTime()
  const totalSeconds = Math.max(0, Math.floor(ms / 1000))
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  if (hours > 0) return `${hours}h ${minutes}m ${seconds}s`
  if (minutes > 0) return `${minutes}m ${seconds}s`
  return `${seconds}s`
}

const END_REASON_MESSAGES: Record<string, string> = {
  time_limit: "This lab was automatically closed because it reached its time limit.",
  idle_timeout: "This lab was automatically closed after 15 minutes of inactivity.",
}

const TASK_STATUS_LABELS: Record<TaskStatus, string> = {
  passed: "Passed",
  skipped: "Skipped",
  pending: "Not completed",
}

const TASK_STATUS_VARIANTS: Record<
  TaskStatus,
  "default" | "secondary" | "outline"
> = {
  passed: "default",
  skipped: "secondary",
  pending: "outline",
}

export default async function LabResultPage({ params }: PageProps) {
  const { sessionId } = await params
  const { session, task_completions } = await apiGet<GetSessionResponse>(`/api/labs/sessions/${sessionId}`)

  if (
    session.status === "provisioning" ||
    session.status === "running" ||
    session.status === "paused"
  ) {
    redirect(ROUTES.labSession(sessionId))
  }

  const lab = await apiGet<Lab>(`/api/labs/${session.lab_id}`)
  const maxScore = lab.tasks.reduce((s, t) => s + t.points, 0)
  const completionMap = new Map(
    task_completions.map((c) => [c.task_id, c]),
  )
  const passedCount = task_completions.filter(
    (c) => c.status === "passed",
  ).length
  const requiredPassed = lab.tasks.filter((t) => {
    if (t.is_optional) return false
    return completionMap.get(t.task_id)?.status === "passed"
  }).length
  const requiredTotal = lab.tasks.filter((t) => !t.is_optional).length
  const didPass = requiredPassed === requiredTotal && requiredTotal > 0

  // Kind labs (debug, ...) add a debrief once the session is completed.
  const Debrief = session.status === "completed" ? LAB_KIND_DEBRIEFS[lab.lab_type] : undefined

  const myFeedback = await getMyFeedback("lab", session.lab_id).catch(() => null)

  return (
    <main className="page-container flex flex-col gap-4">
      <Breadcrumb items={[{ label: "Labs", href: ROUTES.LABS }, { label: lab.title }]} />
      <ClearActiveLabSession sessionId={sessionId} />
      <FeedbackPrompt
        alreadyResponded={myFeedback !== null}
        subjectId={session.lab_id}
        subjectType="lab"
      />
      <header className="card-base flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex min-w-0 items-center gap-3">
          {didPass ? (
            <Trophy aria-hidden className="h-8 w-8 shrink-0 text-primary" />
          ) : (
            <XCircle aria-hidden className="h-8 w-8 shrink-0 text-destructive" />
          )}
          <div className="min-w-0">
            <h1 className="text-xl font-semibold tabular-nums">
              {maxScore > 0 ? `${session.score} / ${maxScore}` : "Done"}
            </h1>
            <p className="text-sm text-muted-foreground">
              {didPass
                ? "All required tasks completed."
                : requiredTotal === 0
                  ? "Lab session ended."
                  : `${requiredPassed} of ${requiredTotal} required tasks passed.`}
              {session.end_reason && ` ${END_REASON_MESSAGES[session.end_reason]}`}
            </p>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-2 text-sm">
          <Badge variant={didPass ? "default" : "secondary"}>
            {passedCount} / {lab.tasks.length} checks passed
          </Badge>
          {session.completed_at && (
            <span className="inline-flex items-center gap-1 text-muted-foreground">
              <Clock aria-hidden className="h-4 w-4" />
              {formatDuration(session.started_at, session.completed_at)}
            </span>
          )}
          {session.reset_count > 0 && (
            <Badge variant="outline">
              {session.reset_count} reset{session.reset_count !== 1 ? "s" : ""}
            </Badge>
          )}
          {session.status === "terminated_abuse" && <Badge variant="destructive">Terminated</Badge>}
          <Button asChild>
            <Link href={ROUTES.lab(session.lab_id)}>New session</Link>
          </Button>
        </div>
      </header>

      {lab.tasks.length > 0 && (
        <section className="card-base flex flex-col divide-y divide-border overflow-hidden">
          <div className="px-4 py-2">
            <h2 className="font-semibold text-sm">Checks</h2>
          </div>
          {lab.tasks.map((task) => {
            const completion = completionMap.get(task.task_id)
            const status: TaskStatus = completion?.status ?? "pending"
            return (
              <div
                className="flex-between gap-3 px-4 py-2"
                key={task.task_id}
              >
                <div className="flex items-center gap-2 min-w-0">
                  {status === "passed" ? (
                    <CheckCircle2
                      aria-hidden
                      className="h-4 w-4 shrink-0 text-success"
                    />
                  ) : (
                    <XCircle
                      aria-hidden
                      className="h-4 w-4 shrink-0 text-muted-foreground"
                    />
                  )}
                  <span className="text-sm font-medium truncate">
                    {task.position}. {task.title}
                  </span>
                  {task.is_optional && (
                    <Badge className="text-xs shrink-0" variant="outline">
                      optional
                    </Badge>
                  )}
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  {completion && completion.attempts > 0 && (
                    <span className="text-xs text-muted-foreground tabular-nums">
                      {completion.attempts} attempt{completion.attempts !== 1 ? "s" : ""}
                    </span>
                  )}
                  <Badge variant={TASK_STATUS_VARIANTS[status]}>
                    {TASK_STATUS_LABELS[status]}
                  </Badge>
                </div>
              </div>
            )
          })}
        </section>
      )}

      {Debrief && <Debrief sessionId={sessionId} />}
    </main>
  )
}
