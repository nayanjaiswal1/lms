"use client"

import { useEffect } from "react"
import { Loader2 } from "lucide-react"
import { Skeleton } from "@/components/ui/skeleton"

interface LabReadinessWaitProps {
  sessionId: string
  onReady: () => void
  onFailed: () => void
}

export function LabReadinessWait({
  sessionId,
  onReady,
  onFailed,
}: LabReadinessWaitProps) {
  const onReadyRef = { current: onReady }
  const onFailedRef = { current: onFailed }
  onReadyRef.current = onReady
  onFailedRef.current = onFailed

  useEffect(() => {
    const es = new EventSource(`/api/labs/sessions/${sessionId}/events`)

    es.onmessage = (e: MessageEvent) => {
      const data = JSON.parse(e.data as string) as { type: string }
      if (data.type === "ready") {
        es.close()
        onReadyRef.current()
      } else if (data.type === "failed") {
        es.close()
        onFailedRef.current()
      }
    }

    es.onerror = () => {
      es.close()
      onFailedRef.current()
    }

    return () => {
      es.close()
    }
  }, [sessionId])

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
