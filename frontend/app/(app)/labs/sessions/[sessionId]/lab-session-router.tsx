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
      onReady={() => router.refresh()}
      onFailed={() => router.refresh()}
    />
  )
}
