import "server-only";

import { apiGet } from "@/lib/server/api";

export type FeedbackSubjectType = "course" | "assessment" | "lab" | "mentor";

export interface Feedback {
  id: string;
  org_id: string;
  subject_type: FeedbackSubjectType;
  subject_id: string;
  user_id: string;
  rating: number | null;
  comment: string | null;
  skipped_at: string | null;
  created_at: string;
  updated_at: string;
}

export async function getMyFeedback(
  subjectType: FeedbackSubjectType,
  subjectId: string,
): Promise<Feedback | null> {
  const data = await apiGet<{ feedback: Feedback | null }>(
    `/api/feedback/${subjectType}/${subjectId}/me`,
  );
  return data.feedback;
}
