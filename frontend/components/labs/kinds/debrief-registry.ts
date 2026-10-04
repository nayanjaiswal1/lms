import type { ReactNode } from "react"
import { DebugDebrief } from "@/components/labs/kinds/debug/debug-debrief"
import type { LabType } from "@/lib/labs"

/** Props every kind debrief section receives on the result page. */
export interface LabDebriefProps {
  sessionId: string
}

type LabDebriefSection = (props: LabDebriefProps) => Promise<ReactNode>

/**
 * lab_type -> server-rendered debrief section (result page, completed
 * sessions only). Server-only, so it lives apart from the client workspace
 * registry. A new kind adds one entry here.
 */
export const LAB_KIND_DEBRIEFS: Partial<Record<LabType, LabDebriefSection>> = {
  debug: DebugDebrief,
}
