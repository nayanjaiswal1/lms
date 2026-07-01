"use client"

import { useRouter } from "next/navigation"
import { LabReadinessWait } from "@/components/labs/lab-readiness-wait"
import ROUTES from "@/lib/routes"

interface LabSessionRouterProps {
  sessionId: string
  labId: string
}

export function LabSessionRouter({ sessionId, labId }: LabSessionRouterProps) {
  const router = useRouter()

  return (
    <LabReadinessWait
      sessionId={sessionId}
      onReady={() => router.refresh()}
      onFailed={() => router.push(ROUTES.lab(labId))}
    />
  )
}
