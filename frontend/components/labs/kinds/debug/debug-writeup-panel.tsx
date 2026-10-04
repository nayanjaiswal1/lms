"use client"

import { AlertCircle, FileText, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { DebugWriteupReviewCard } from "@/components/labs/kinds/debug/debug-writeup-review-card"
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
          Fill in <code>{DEBUG_WRITEUP_FILE}</code> in the IDE, then submit it for review.
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

      {result && <DebugWriteupReviewCard result={result} />}
    </section>
  )
}
