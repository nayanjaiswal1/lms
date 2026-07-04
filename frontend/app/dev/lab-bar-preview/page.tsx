import { LabProvisioningProvider } from "@/lib/labs/provisioning-context"
import { ActiveLabsBar } from "@/components/labs/active-labs-bar"
import type { ActiveLabSession } from "@/lib/labs"

const RUNNING_SESSION: ActiveLabSession = {
  session_id: "preview-session-running",
  lab_id: "preview-lab",
  lab_title: "Kubernetes Networking Fundamentals",
  lab_type: "terminal",
  status: "running",
  started_at: new Date().toISOString(),
  expires_at: new Date(Date.now() + 3600_000).toISOString(),
  last_active_at: new Date().toISOString(),
}

export default function LabBarPreviewPage() {
  return (
    <div className="min-h-dvh bg-background p-8">
      <h1 className="page-title">Lab bar style preview</h1>
      <p className="text-muted-foreground">Temporary dev-only route to iterate on ActiveLabsBar styling.</p>
      <LabProvisioningProvider initialSession={RUNNING_SESSION}>
        <ActiveLabsBar />
      </LabProvisioningProvider>
    </div>
  )
}
