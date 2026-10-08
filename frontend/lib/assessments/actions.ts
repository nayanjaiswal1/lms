"use server";

import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import type { ExperienceValue } from "@/lib/server/feedback";

/** The post-attempt "did anything go wrong?" report (feedback kind experience). */
export async function submitExperienceReportAction(input: {
  subjectId: string;
  experience?: ExperienceValue;
  description?: string;
  skip?: boolean;
}): Promise<ActionResult> {
  return apiAction("POST", "/api/feedback", {
    subject_type: "assessment",
    subject_id: input.subjectId,
    kind: "experience",
    experience: input.experience,
    comment: input.description,
    skip: input.skip ?? false,
  });
}
