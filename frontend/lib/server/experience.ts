import "server-only";

import { apiGet } from "@/lib/server/api";

export type ExperienceSubjectType = "assessment";
export type ExperienceValue = "smooth" | "issue" | "complaint";

export interface ExperienceReport {
  id: string;
  org_id: string;
  subject_type: ExperienceSubjectType;
  subject_id: string;
  user_id: string;
  experience: ExperienceValue | null;
  description: string | null;
  skipped_at: string | null;
  created_at: string;
  updated_at: string;
}

export async function getMyExperienceReport(
  subjectType: ExperienceSubjectType,
  subjectId: string,
): Promise<ExperienceReport | null> {
  const data = await apiGet<{ report: ExperienceReport | null }>(
    `/api/experience-reports/${subjectType}/${subjectId}/me`,
  );
  return data.report;
}
