import { TriangleAlert } from "lucide-react"
import { IconMessage } from "@/components/shared/icon-message"
import type { MissionPhase } from "@/hooks/use-mission-clock"

interface MissionBannerProps {
  phase: MissionPhase
}

/** Strip under the header while the final submit is imminent or running. */
export function MissionBanner({ phase }: MissionBannerProps) {
  if (phase !== "ending" && phase !== "expired") return null
  return (
    <IconMessage icon={TriangleAlert} role="status" size="xs" variant="strip">
      {phase === "expired"
        ? "Mission time expired — auto-submitting your patch…"
        : "Time is almost up — your patch is auto-submitted in a moment."}
    </IconMessage>
  )
}
