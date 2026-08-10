"use client"

import { Loader2 } from "lucide-react"
import { useLabReadiness } from "@/lib/labs/use-lab-readiness"

interface LabReadinessInlineProps {
  sessionId: string
  onReady: () => void
  onFailed: () => void
}

// Course-page counterpart to <LabReadinessWait> — same useLabReadiness SSE
// wait, but scoped to the lab card's own footprint instead of a fixed
// full-screen takeover, so the rest of the lesson (nav, header, article)
// stays visible while the session provisions.
export function LabReadinessInline({ sessionId, onReady, onFailed }: LabReadinessInlineProps) {
  useLabReadiness(sessionId, { onReady, onFailed })

  return (
    <div className="card-base flex flex-col items-center gap-3 p-6 text-center">
      <Loader2 aria-hidden className="h-8 w-8 animate-spin text-primary" />
      <div className="flex flex-col gap-1">
        <p className="font-semibold text-foreground">Starting your lab environment…</p>
        <p className="text-sm text-muted-foreground">
          Provisioning your sandbox. This usually takes 10–30 seconds.
        </p>
      </div>
    </div>
  )
}
