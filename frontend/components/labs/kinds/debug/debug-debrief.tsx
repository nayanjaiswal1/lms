import { DebugChangeViewer } from "@/components/labs/kinds/debug/debug-change-viewer"
import { DebugWriteupReviewCard } from "@/components/labs/kinds/debug/debug-writeup-review-card"
import { LabMarkdown } from "@/components/labs/kinds/debug/lab-markdown"
import { apiGet } from "@/lib/server/api"
import type { LabDebriefProps } from "@/components/labs/kinds/debrief-registry"
import type { DebugDebriefResponse } from "@/lib/labs/kinds/debug"

/** Post-completion debrief: what the root cause was, and the reference fix beside the student's own diff. */
export async function DebugDebrief({ sessionId }: LabDebriefProps) {
  // The debrief is a bonus on the result page — never fail the page over it.
  const data = await apiGet<DebugDebriefResponse>(
    `/api/labs/sessions/${sessionId}/debrief`,
  ).catch(() => null)
  if (!data) return null

  const { debrief, student_diff, writeup_review } = data

  return (
    <>
      <section aria-labelledby="debrief-root-cause" className="flex flex-col gap-3">
        <h2 className="subsection-title" id="debrief-root-cause">
          What went wrong
        </h2>
        <div className="max-w-prose">
          <LabMarkdown>{debrief.root_cause}</LabMarkdown>
        </div>
      </section>

      <section aria-labelledby="debrief-diff" className="flex flex-col gap-3">
        <h2 className="subsection-title" id="debrief-diff">
          The change
        </h2>
        <DebugChangeViewer referenceDiff={debrief.fix_diff} studentDiff={student_diff ?? ""} />
      </section>

      {writeup_review && (
        <section aria-labelledby="debrief-writeup" className="flex flex-col gap-2">
          <h2 className="subsection-title" id="debrief-writeup">
            Your write-up review
          </h2>
          <DebugWriteupReviewCard result={writeup_review} />
        </section>
      )}
    </>
  )
}
