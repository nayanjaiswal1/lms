import type { Lab, LabKindBlock, LabSession, TaskCompletion } from "@/lib/labs"

/**
 * Live verify state reported upward for hosts that need it outside this
 * component's own checklist/workspace rendering — e.g. the course notes
 * embed, where "Check my progress" cards are scattered through the lesson
 * body instead of living in a single checklist. Sourced from this
 * component's own `useLabVerify` instance so there's exactly one source of
 * truth: the terminal's built-in Check button and the external cards drive
 * (and reflect) the same state.
 */
export interface LabVerifyBridge {
  completions: TaskCompletion[]
  isVerifying: boolean
  selectedTaskId: string | null
  /** Selects the task (so the workspace panel targets it too) and verifies it. */
  checkTask: (taskId: string) => void
}

export interface LabWorkspaceContentProps {
  session: LabSession
  lab: Lab
  initialCompletions: TaskCompletion[]
  /** Split direction of the desktop task/workspace panels. */
  orientation?: "horizontal" | "vertical"
  /**
   * Increment to clear all verify state (completions, score, editor code)
   * after a successful server-side lab reset.
   */
  resetNonce?: number
  /**
   * How a "console" layout lab renders on desktop: "boxed" keeps the
   * checklist + terminal drawer confined to this component's own bounded
   * parent (the full-screen /labs/[labId] environment). "fixed" flows the
   * checklist inline with the rest of the page and pins the terminal to the
   * bottom of the browser viewport instead (the course notes embed).
   */
  consoleMode?: "boxed" | "fixed"
  /**
   * Skip rendering the built-in `<LabTaskChecklist>` in the fixed console
   * branch. Used by the course notes embed, which renders its own scattered
   * per-task cards instead — driven by `onVerifyStateChange` below rather
   * than a second checklist.
   */
  hideTaskChecklist?: boolean
  onVerifyStateChange?: (bridge: LabVerifyBridge) => void
  onScoreChange?: (score: number) => void
  onAuthExpiredChange?: (expired: boolean) => void
  onLogin: () => void
  /** Kind-specific block from GET /sessions/:id; only lab kinds read it. */
  kindBlock?: LabKindBlock
}
