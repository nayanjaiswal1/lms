// Presentation map for Meeting.kind (models_phase3.go MeetingKinds) — same
// colocated-constants pattern as items-constants.ts.
import type { MeetingKind } from "@/lib/workspace/types";

export const MEETING_KIND_LABEL: Record<MeetingKind, string> = {
  kickoff: "Kickoff",
  sprint_planning: "Sprint planning",
  standup: "Standup",
  design_review: "Design review",
  retro: "Retro",
  demo: "Demo",
};
