import type { Metadata } from "next"
import { redirect } from "next/navigation"
import { Breadcrumb } from "@/components/shared/breadcrumb"
import { LAB_KIND_DEBRIEFS } from "@/components/labs/kinds/debrief-registry"
import { ClearActiveLabSession } from "@/components/labs/clear-active-lab-session"
import { ResultChecks } from "@/components/labs/result/result-checks"
import { ResultHeader } from "@/components/labs/result/result-header"
import { ResultMissedPoints } from "@/components/labs/result/result-missed-points"
import { ResultNext } from "@/components/labs/result/result-next"
import { FeedbackPrompt } from "@/components/feedback/feedback-prompt"
import { apiGet } from "@/lib/server/api"
import { getMyFeedback } from "@/lib/server/feedback"
import ROUTES from "@/lib/routes"
import type { Lab, GetSessionResponse } from "@/lib/labs"

export const metadata: Metadata = {
  title: "Lab Result",
  robots: { index: false, follow: false },
}

interface PageProps {
  params: Promise<{ sessionId: string }>
}

export default async function LabResultPage({ params }: PageProps) {
  const { sessionId } = await params
  const { session, task_completions } = await apiGet<GetSessionResponse>(`/api/labs/sessions/${sessionId}`)

  if (session.status === "provisioning" || session.status === "running" || session.status === "paused") {
    redirect(ROUTES.labSession(sessionId))
  }

  const lab = await apiGet<Lab>(`/api/labs/${session.lab_id}`)
  const completions = new Map(task_completions.map((c) => [c.task_id, c]))
  const required = lab.tasks.filter((t) => !t.is_optional)
  const requiredPassed = required.filter((t) => completions.get(t.task_id)?.status === "passed").length
  const didPass = required.length > 0 && requiredPassed === required.length

  // Kind labs (debug, ...) add a debrief once the session is completed.
  const Debrief = session.status === "completed" ? LAB_KIND_DEBRIEFS[lab.lab_type] : undefined

  const myFeedback = await getMyFeedback("lab", session.lab_id).catch(() => null)

  return (
    <main className="page-container flex max-w-4xl flex-col gap-6 pb-24">
      <Breadcrumb items={[{ label: "Labs", href: ROUTES.LABS_CATALOG }, { label: "Result" }]} />
      <ClearActiveLabSession sessionId={sessionId} />
      <ResultHeader
        didPass={didPass}
        hintsUsed={task_completions.reduce((sum, c) => sum + c.hints_used, 0)}
        labType={lab.lab_type}
        maxScore={lab.tasks.reduce((s, t) => s + t.points, 0)}
        passedChecks={task_completions.filter((c) => c.status === "passed").length}
        score={session.score}
        session={session}
        title={lab.title}
        totalChecks={lab.tasks.length}
      />
      <ResultMissedPoints completions={completions} tasks={lab.tasks} />
      {lab.tasks.length > 0 && <ResultChecks completions={completions} tasks={lab.tasks} />}
      {Debrief && <Debrief sessionId={sessionId} />}
      <FeedbackPrompt alreadyResponded={myFeedback !== null} subjectId={session.lab_id} subjectType="lab" />
      <ResultNext labId={session.lab_id} />
    </main>
  )
}
