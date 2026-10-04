import type { ComponentType } from "react"
import { DebugWorkspace } from "@/components/labs/kinds/debug/debug-workspace"
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
