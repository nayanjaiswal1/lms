"use client"

import { useEffect, useRef } from "react"
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
  const onReadyRef = useRef(onReady)
  const onFailedRef = useRef(onFailed)
  onReadyRef.current = onReady
  onFailedRef.current = onFailed

  useEffect(() => {
    const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? ""
    const es = new EventSource(`${apiUrl}/api/labs/sessions/${sessionId}/events`, {
      withCredentials: true,
    })

    // Safety backstop against a lab that never resolves — must clear the
    // longest legitimate provisioning path server-side (see
    // labs.ProvisionTimeoutSeconds, 180s: nested-Docker labs on a proxied-
    // socket host run a doomed scoped attempt to completion before their
    // privileged retry boots dockerd for real).
    const safetyTimer = setTimeout(() => onFailedRef.current(), 200_000)

    es.onmessage = (e: MessageEvent) => {
      const data = JSON.parse(e.data as string) as { type: string }
      if (data.type === "ready") {
        clearTimeout(safetyTimer)
        es.close()
        onReadyRef.current()
      } else if (data.type === "failed") {
        clearTimeout(safetyTimer)
        es.close()
        onFailedRef.current()
      }
    }

    // The connection can drop for transient reasons (proxy hiccup, brief
    // network loss); the browser retries EventSource automatically, so this
    // must not be treated as a hard failure — the safety timeout above is
    // the real backstop. See the identical comment in
    // lab-provisioning-watcher.tsx, which this mirrors.

    return () => {
      clearTimeout(safetyTimer)
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
