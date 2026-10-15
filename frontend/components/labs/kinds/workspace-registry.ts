import type { ComponentType } from "react"
import { DebugWorkspace } from "@/components/labs/kinds/debug/debug-workspace"
import { MissionWorkspace } from "@/components/labs/kinds/debug/mission/mission-workspace"
import { DEBUG_UI_MODE, type DebugUiMode } from "@/lib/constants"
import type { Lab, LabKindBlock, LabSession, LabType, TaskCompletion } from "@/lib/labs"

/** Props every kind workspace receives from LabWorkspaceContent. */
export interface LabKindWorkspaceProps {
  session: LabSession
  lab: Lab
  initialCompletions: TaskCompletion[]
  /** The kind's student-safe block from GET /sessions/:id. */
  kindBlock: LabKindBlock
  /** Increment after a successful server-side reset; the workspace remounts its state. */
  resetNonce: number
  onScoreChange?: (score: number) => void
  onAuthExpiredChange?: (expired: boolean) => void
  onLogin: () => void
  /** Reset affordance for workspaces that replace the host's top bar (mission mode). */
  onReset?: () => void
  resetsLeft?: number
  isResetting?: boolean
}

/**
 * lab_type -> workspace component for lab kinds. A new kind adds one entry
 * here (plus its block in LabKindBlocks, its debrief in debrief-registry.tsx
 * and, if it is browsable, its catalog config in lib/labs/kinds/catalog.ts);
 * LabWorkspaceContent itself does not change.
 */
export const LAB_KIND_WORKSPACES: Partial<Record<LabType, ComponentType<LabKindWorkspaceProps>>> = {
  debug: DebugWorkspace,
}

/**
 * Alternative workspaces a kind offers when its org picks the new UI
 * (org_settings.labs.debug_ui = "new", resolved server-side into
 * GET /sessions/:id -> lab_ui). They bring their own top bar.
 */
const LAB_KIND_MISSION_WORKSPACES: Partial<Record<LabType, ComponentType<LabKindWorkspaceProps>>> = {
  debug: MissionWorkspace,
}

/** The workspace a kind lab renders for the org's UI mode; undefined for non-kind labs. */
export function pickKindWorkspace(labType: LabType, labUi: DebugUiMode | undefined) {
  if (labUi === DEBUG_UI_MODE.NEW) {
    return LAB_KIND_MISSION_WORKSPACES[labType] ?? LAB_KIND_WORKSPACES[labType]
  }
  return LAB_KIND_WORKSPACES[labType]
}

/** True when the lab renders a mission workspace (which replaces the host's top bar). */
export function usesMissionWorkspace(labType: LabType, labUi: DebugUiMode | undefined) {
  return labUi === DEBUG_UI_MODE.NEW && LAB_KIND_MISSION_WORKSPACES[labType] !== undefined
}
