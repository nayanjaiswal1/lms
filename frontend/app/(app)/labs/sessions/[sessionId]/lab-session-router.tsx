"use client"

import { useRouter } from "next/navigation"
import { LabReadinessWait } from "@/components/labs/lab-readiness-wait"

interface LabSessionRouterProps {
  sessionId: string
}

export function LabSessionRouter({ sessionId }: LabSessionRouterProps) {
  const router = useRouter()

  return (
    <LabReadinessWait
      sessionId={sessionId}
      onFailed={() => router.refresh()}
      onReady={() => router.refresh()}
    />
  )
}
