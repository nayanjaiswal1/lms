import { Lightbulb } from "lucide-react"
import { DebugDiffView } from "@/components/labs/kinds/debug/debug-diff-view"
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

  const { debrief, student_diff } = data

  return (
    <>
      <section aria-labelledby="debrief-root-cause" className="card-base flex flex-col gap-3 p-6">
        <h2 className="flex items-center gap-2 text-sm font-semibold" id="debrief-root-cause">
          <Lightbulb aria-hidden className="h-4 w-4 text-primary" />
          Root cause
        </h2>
        <LabMarkdown>{debrief.root_cause}</LabMarkdown>
      </section>

      <section aria-labelledby="debrief-diff" className="card-base flex flex-col gap-4 p-6">
        <h2 className="text-sm font-semibold" id="debrief-diff">
          Reference fix vs your changes
        </h2>
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
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
    </>
  )
}
