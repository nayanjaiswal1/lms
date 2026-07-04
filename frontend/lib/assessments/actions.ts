"use server";

import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import type { ExperienceSubjectType, ExperienceValue } from "@/lib/server/experience";

export async function submitExperienceReportAction(input: {
  subjectType: ExperienceSubjectType;
  subjectId: string;
  experience?: ExperienceValue;
  description?: string;
  skip?: boolean;
}): Promise<ActionResult> {
  return apiAction("POST", "/api/experience-reports", {
    subject_type: input.subjectType,
    subject_id: input.subjectId,
    experience: input.experience,
    description: input.description,
    skip: input.skip ?? false,
  });
}
