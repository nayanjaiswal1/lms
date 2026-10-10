import Link from "next/link"
import { Clock } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import ROUTES from "@/lib/routes"
import { formatDuration } from "@/components/labs/result/format-duration"
import type { GetSessionResponse } from "@/lib/labs"

const END_REASON_MESSAGES: Record<string, string> = {
  time_limit: "Closed automatically at the time limit.",
  idle_timeout: "Closed automatically after 15 minutes of inactivity.",
}

interface ResultHeaderProps {
  labId: string
  title: string
  session: GetSessionResponse["session"]
  score: number
  maxScore: number
  passedChecks: number
  totalChecks: number
  didPass: boolean
}

/** h1 (lab title) + one compact stats row + the retry CTA. */
export function ResultHeader({
  labId,
  title,
  session,
  score,
  maxScore,
  passedChecks,
  totalChecks,
  didPass,
}: ResultHeaderProps) {
  const note = session.end_reason ? END_REASON_MESSAGES[session.end_reason] : undefined

  return (
    <header className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div className="flex min-w-0 flex-col gap-2">
        <div className="flex flex-wrap items-center gap-2">
          <Badge variant={didPass ? "default" : "secondary"}>{didPass ? "Passed" : "Not passed"}</Badge>
          {session.status === "terminated_abuse" && <Badge variant="destructive">Terminated</Badge>}
        </div>
        <h1 className="page-title">{title}</h1>
        <p className="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-muted-foreground tabular-nums">
          {maxScore > 0 && (
            <span>
              <strong className="text-foreground">{score}</strong> / {maxScore} points
            </span>
          )}
          <span>
            {passedChecks} of {totalChecks} checks
          </span>
          {session.completed_at && (
            <span className="inline-flex items-center gap-1">
              <Clock aria-hidden className="h-3.5 w-3.5" />
              {formatDuration(session.started_at, session.completed_at)}
            </span>
          )}
          {session.reset_count > 0 && (
            <span>
              {session.reset_count} reset{session.reset_count !== 1 ? "s" : ""}
            </span>
          )}
        </p>
        {note && <p className="text-xs text-muted-foreground">{note}</p>}
      </div>
      <Button asChild className="w-full sm:w-auto">
        <Link href={ROUTES.lab(labId)}>New session</Link>
      </Button>
    </header>
  )
}
