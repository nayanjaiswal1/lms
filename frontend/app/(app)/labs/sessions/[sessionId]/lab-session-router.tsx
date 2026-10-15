"use client"

import { useRouter } from "next/navigation"
import { LabReadinessWait } from "@/components/labs/lab-readiness-wait"

interface LabSessionRouterProps {
  sessionId: string
  /** Set for orgs on the mission debug UI: the lab title shown on the build screen. */
  missionTitle?: string
}

export function LabSessionRouter({ sessionId, missionTitle }: LabSessionRouterProps) {
  const router = useRouter()

  return (
    <LabReadinessWait
      missionTitle={missionTitle}
      sessionId={sessionId}
      onFailed={() => router.refresh()}
      onReady={() => router.refresh()}
    />
  )
}
