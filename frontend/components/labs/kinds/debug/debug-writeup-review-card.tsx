import { CheckCircle2, Sparkles } from "lucide-react"
import type { WriteupReviewResult } from "@/lib/labs/kinds/debug"

interface DebugWriteupReviewCardProps {
  result: WriteupReviewResult
}

/** One AI write-up review: verdict, feedback and the rubric points it credited (AI = cyan surface). */
export function DebugWriteupReviewCard({ result }: DebugWriteupReviewCardProps) {
  return (
    <div aria-live="polite" className="ai-surface flex flex-col gap-2 p-3">
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
  )
}
