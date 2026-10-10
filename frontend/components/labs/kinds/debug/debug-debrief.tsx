import { DebugDiffView } from "@/components/labs/kinds/debug/debug-diff-view"
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
      <section aria-labelledby="debrief-root-cause" className="flex flex-col gap-2">
        <h2 className="subsection-title" id="debrief-root-cause">
          Root cause
        </h2>
        <LabMarkdown>{debrief.root_cause}</LabMarkdown>
      </section>

      <section aria-labelledby="debrief-diff" className="flex flex-col gap-2">
        <h2 className="subsection-title" id="debrief-diff">
          Reference fix vs your changes
        </h2>
        <div className="flex flex-col gap-4">
          <DebugDiffView
            diff={debrief.fix_diff}
            emptyMessage="No reference diff for this scenario."
            title="Reference fix"
          />
          <DebugDiffView
            diff={student_diff ?? ""}
            emptyMessage="Your workspace changes are no longer available."
            title="Your changes"
          />
        </div>
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
