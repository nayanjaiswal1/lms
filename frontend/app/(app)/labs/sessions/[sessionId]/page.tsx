import type { Metadata } from "next"
import Link from "next/link"
import { redirect } from "next/navigation"
import { AlertCircle } from "lucide-react"
import { Button } from "@/components/ui/button"
import { LabEnvironment } from "@/components/labs/lab-environment"
import { LabSessionRouter } from "@/app/(app)/labs/sessions/[sessionId]/lab-session-router"
import { apiGet, apiPost } from "@/lib/server/api"
import ROUTES from "@/lib/routes"
import type { Lab, GetSessionResponse } from "@/lib/labs"

export const metadata: Metadata = {
  title: "Lab Session",
  robots: { index: false, follow: false },
}

interface PageProps {
  params: Promise<{ sessionId: string }>
}

export default async function LabSessionPage({ params }: PageProps) {
  const { sessionId } = await params
  const { session, task_completions } = await apiGet<GetSessionResponse>(`/api/labs/sessions/${sessionId}`)

  if (
    session.status === "completed" ||
    session.status === "expired" ||
    session.status === "terminated_abuse"
  ) {
    redirect(ROUTES.labSessionResult(sessionId))
  }

  const lab = await apiGet<Lab>(`/api/labs/${session.lab_id}`)

  if (session.status === "provisioning") {
    return <LabSessionRouter sessionId={sessionId} labId={session.lab_id} />
  }

  if (session.status === "failed") {
    return (
      <main className="page-container-sm py-10">
        <div className="card-raised flex flex-col items-center gap-4 p-8 text-center">
          <AlertCircle aria-hidden className="h-12 w-12 text-destructive" />
          <div className="flex flex-col gap-1">
            <h1 className="text-xl font-bold">Lab failed to start</h1>
            <p className="text-muted-foreground text-sm">
              The lab environment could not be provisioned. This is usually a
              temporary infrastructure issue.
            </p>
          </div>
          <Button asChild>
            <Link href={ROUTES.lab(session.lab_id)}>Try Again</Link>
          </Button>
        </div>
      </main>
    )
  }

  // running | paused
  const { session_token: wsToken } = await apiPost<{ session_token: string }>(
    `/api/labs/sessions/${sessionId}/ws-token`,
  )

  return <LabEnvironment session={session} lab={lab} wsToken={wsToken} initialCompletions={task_completions} />
}
