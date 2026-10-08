import "server-only";

import { apiGet } from "@/lib/server/api";

export type FeedbackSubjectType = "course" | "assessment" | "lab" | "mentor";

/** rating = 1-5 stars; experience = the "did anything go wrong?" report. */
export type FeedbackKind = "rating" | "experience";
export type ExperienceValue = "smooth" | "issue" | "complaint";

export interface Feedback {
  id: string;
  org_id: string;
  subject_type: FeedbackSubjectType;
  subject_id: string;
  user_id: string;
  kind: FeedbackKind;
  rating: number | null;
  experience: ExperienceValue | null;
  comment: string | null;
  skipped_at: string | null;
  created_at: string;
  updated_at: string;
}

export async function getMyFeedback(
  subjectType: FeedbackSubjectType,
  subjectId: string,
  kind: FeedbackKind = "rating",
): Promise<Feedback | null> {
  const data = await apiGet<{ feedback: Feedback | null }>(
    `/api/feedback/${subjectType}/${subjectId}/me?kind=${kind}`,
  );
  return data.feedback;
}

export interface PublicReview {
  id: string;
  reviewer_name: string;
  reviewer_role: string | null;
  rating: number;
  comment: string;
  created_at: string;
}

export async function getPublicFeedback(
  subjectType: FeedbackSubjectType,
  subjectId: string,
  limit?: number,
): Promise<PublicReview[]> {
  const query = limit ? `?limit=${limit}` : "";
  const data = await apiGet<{ reviews: PublicReview[] }>(
    `/api/feedback/${subjectType}/${subjectId}${query}`,
  );
  return data.reviews ?? [];
}
