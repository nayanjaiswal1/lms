import { Clock, Lightbulb } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { displayLabTitle } from "@/components/labs/result/display-title"
import { formatDuration } from "@/components/labs/result/format-duration"
import { ScoreRing } from "@/components/labs/result/score-ring"
import type { GetSessionResponse, LabType } from "@/lib/labs"

const END_REASON_MESSAGES: Record<string, string> = {
  time_limit: "Closed automatically at the time limit.",
  idle_timeout: "Closed automatically after 15 minutes of inactivity.",
}

/** Verdict wording per lab kind; kinds without an entry use the generic pair. */
const VERDICTS: Partial<Record<LabType, { pass: string; fail: string }>> = {
  debug: { pass: "Fixed", fail: "Not fixed yet" },
}
const DEFAULT_VERDICT = { pass: "Passed", fail: "Not passed" }

interface ResultHeaderProps {
  title: string
  labType: LabType
  session: GetSessionResponse["session"]
  score: number
  maxScore: number
  passedChecks: number
  totalChecks: number
  hintsUsed: number
  didPass: boolean
}

/** Score ring, one-sentence verdict and the session facts. */
export function ResultHeader({
  title,
  labType,
  session,
  score,
  maxScore,
  passedChecks,
  totalChecks,
  hintsUsed,
  didPass,
}: ResultHeaderProps) {
  const verdict = VERDICTS[labType] ?? DEFAULT_VERDICT
  const note = session.end_reason ? END_REASON_MESSAGES[session.end_reason] : undefined
  const verdictText = `${didPass ? verdict.pass : verdict.fail}${maxScore > 0 ? ` – ${score} of ${maxScore} points` : ""}`

  return (
    <header className="card-base flex flex-col items-center gap-5 text-center sm:flex-row sm:text-left">
      {maxScore > 0 && <ScoreRing maxScore={maxScore} score={score} />}
      <div className="flex min-w-0 flex-col items-center gap-1.5 sm:items-start">
        <p className="text-sm text-muted-foreground">{displayLabTitle(title)}</p>
        <h1 className="page-title">{verdictText}</h1>
        <ul className="flex flex-wrap justify-center gap-x-4 gap-y-1 text-sm text-muted-foreground tabular-nums sm:justify-start">
          <li>
            {passedChecks} of {totalChecks} checks passed
          </li>
          {session.completed_at && (
            <li className="inline-flex items-center gap-1">
              <Clock aria-hidden className="h-3.5 w-3.5" />
              {formatDuration(session.started_at, session.completed_at)}
            </li>
          )}
          <li className="inline-flex items-center gap-1">
            <Lightbulb aria-hidden className="h-3.5 w-3.5" />
            {hintsUsed} {hintsUsed === 1 ? "hint" : "hints"} used
          </li>
          {session.reset_count > 0 && (
            <li>
              {session.reset_count} reset{session.reset_count !== 1 ? "s" : ""}
            </li>
          )}
        </ul>
        {session.status === "terminated_abuse" && <Badge variant="destructive">Terminated</Badge>}
        {note && <p className="text-xs text-muted-foreground">{note}</p>}
      </div>
    </header>
  )
}
