import "server-only";

import { apiGet } from "@/lib/server/api";

export interface RevisionPlanTopic {
  id: string;
  module_id: string | null;
  title: string;
  reason: string;
  recommendation: string;
  priority: number;
  position: number;
}

export type RevisionPlanStatus = "generating" | "ready" | "failed";

export interface RevisionPlan {
  id: string;
  course_id: string;
  status: RevisionPlanStatus;
  generation_error?: string | null;
  generated_at: string | null;
  topics?: RevisionPlanTopic[];
  created_at: string;
  updated_at: string;
}

// Null means the learner hasn't requested a plan for this course yet — not
// an error. The generate button (see components/revision-plan) is the only
// way a row starts existing.
export async function getRevisionPlan(courseID: string): Promise<RevisionPlan | null> {
  const data = await apiGet<{ plan: RevisionPlan | null }>(`/api/courses/${courseID}/revision-plan/me`);
  return data.plan;
}
