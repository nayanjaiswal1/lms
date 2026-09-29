"use client"

import { AlertCircle, CheckCircle2, FileText, Loader2, Sparkles } from "lucide-react"
import { Button } from "@/components/ui/button"
import { IconMessage } from "@/components/shared/icon-message"
import { DEBUG_WRITEUP_FILE, type WriteupReviewResult } from "@/lib/labs/kinds/debug"

interface DebugWriteupPanelProps {
  result: WriteupReviewResult | null
  error: string | null
  remaining: number
  isReviewing: boolean
  onSubmit: () => void
}

/** Write-up step: AI reviews INCIDENT.md against the rubric (AI content = cyan surface). */
export function DebugWriteupPanel({
  result,
  error,
  remaining,
  isReviewing,
  onSubmit,
}: DebugWriteupPanelProps) {
  return (
    <section aria-label="Incident write-up" className="card-base flex flex-col gap-3 p-4">
      <div className="flex flex-col gap-1">
        <h3 className="flex items-center gap-2 text-sm font-semibold">
          <FileText aria-hidden className="h-4 w-4 text-muted-foreground" />
          Root-cause write-up
        </h3>
        <p className="text-xs text-muted-foreground">
          Fill in <code>{DEBUG_WRITEUP_FILE}</code> in the IDE, then submit it for review. The lab
          ends as soon as the required checks pass, so submit your write-up before your final
          passing Check.
        </p>
      </div>

      <Button
        className="w-full touch-target gap-2"
        disabled={isReviewing || remaining <= 0}
        variant="outline"
        onClick={onSubmit}
      >
        {isReviewing ? (
          <>
            <Loader2 aria-hidden className="h-4 w-4 animate-spin" />
            Reviewing…
          </>
        ) : (
          "Submit write-up"
        )}
      </Button>
      <p aria-live="polite" className="text-xs text-muted-foreground">
        {remaining > 0
          ? `${remaining} review${remaining === 1 ? "" : "s"} remaining`
          : "No reviews remaining for this session."}
      </p>

      {error && (
        <IconMessage icon={AlertCircle} role="alert" tone="destructive">
          {error}
        </IconMessage>
      )}

      {result && (
        <div aria-live="polite" className="ai-surface flex flex-col gap-3 p-4">
          <div className="flex items-center justify-between gap-2">
            <span className="ai-badge inline-flex items-center gap-1">
              <Sparkles aria-hidden className="h-3 w-3" />
              AI review
            </span>
            <span className="text-xs font-medium">
              {result.passed
                ? `Passed${result.score_added > 0 ? ` · +${result.score_added} pts` : ""}`
                : "Not there yet"}
            </span>
          </div>
          <p className="text-sm leading-relaxed">{result.feedback}</p>
          {result.covered.length > 0 && (
            <ul className="flex flex-col gap-1.5">
              {result.covered.map((point) => (
                <li className="flex items-start gap-2 text-sm" key={point}>
                  <CheckCircle2 aria-hidden className="mt-0.5 h-4 w-4 shrink-0 text-success" />
                  <span className="min-w-0 break-words">{point}</span>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </section>
  )
}
