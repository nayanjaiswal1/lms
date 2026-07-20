"use server";

import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import type { RevisionPlan } from "@/lib/server/revision-plan";

// Kicks off (or restarts, if a previous attempt failed) async AI generation
// of the caller's revision plan for a completed course. The backend rejects
// with 422 if the course isn't fully completed yet — see
// backend/internal/revisionplan.ErrCourseNotComplete.
export async function generateRevisionPlanAction(courseID: string): Promise<ActionResult<RevisionPlan>> {
  return apiAction<RevisionPlan>("POST", `/api/courses/${courseID}/revision-plan`);
}
