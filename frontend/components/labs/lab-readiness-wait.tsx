"use client"

import { Loader2 } from "lucide-react"
import { Skeleton } from "@/components/ui/skeleton"
import { useLabReadiness } from "@/lib/labs/use-lab-readiness"

interface LabReadinessWaitProps {
  sessionId: string
  onReady: () => void
  onFailed: () => void
}

// Full-screen takeover for the dedicated /labs/sessions/[sessionId] route —
// that route *is* the lab, so covering the viewport while it provisions is
// correct there. Course-page callers (LessonLabHero, ModuleLabClient) use
// <LabReadinessInline> instead, which shares useLabReadiness but stays
// scoped to the lab card's own footprint.
export function LabReadinessWait({
  sessionId,
  onReady,
  onFailed,
}: LabReadinessWaitProps) {
  useLabReadiness(sessionId, { onReady, onFailed })

  return (
    <div className="fixed inset-0 bg-background z-modal flex flex-col safe-inset">
      {/* Blurred skeleton of the lab layout behind the loading indicator */}
      <div className="absolute inset-0 flex flex-col opacity-20 blur-sm pointer-events-none" aria-hidden>
        <div className="h-14 shrink-0 border-b border-border bg-card" />
        <div className="flex flex-1 overflow-hidden">
          <div className="w-80 shrink-0 border-r border-border p-4 flex flex-col gap-3">
            <Skeleton className="h-6 w-32" />
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-3/4" />
          </div>
          <div className="flex-1 p-4 flex flex-col gap-3">
            <Skeleton className="h-full w-full" />
          </div>
        </div>
      </div>

      {/* Foreground loading state */}
      <div className="relative z-raised flex flex-col items-center justify-center h-full gap-4 px-6 text-center">
        <Loader2
          aria-hidden
          className="h-10 w-10 animate-spin text-primary"
        />
        <div className="flex flex-col gap-1">
          <p className="font-semibold text-foreground">Starting your lab environment…</p>
          <p className="text-sm text-muted-foreground max-w-xs">
            Provisioning your sandbox. This usually takes 10–30 seconds.
          </p>
        </div>
      </div>
    </div>
  )
}
