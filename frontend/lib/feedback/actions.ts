"use server";

import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import type { FeedbackSubjectType } from "@/lib/server/feedback";

export async function submitFeedbackAction(input: {
  subjectType: FeedbackSubjectType;
  subjectId: string;
  rating?: number;
  comment?: string;
  skip?: boolean;
}): Promise<ActionResult> {
  return apiAction("POST", "/api/feedback", {
    subject_type: input.subjectType,
    subject_id: input.subjectId,
    rating: input.rating,
    comment: input.comment,
    skip: input.skip ?? false,
  });
}
