"use server";

import { revalidatePath } from "next/cache";
import { apiAction, ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { ProctoringConfig } from "@/lib/assessments/types";

export type { ActionResult };

export interface CreateAssessmentInput {
  title: string;
  description?: string;
  parent_type: string;
  duration_minutes: number;
  pass_percentage: number;
  max_attempts: number;
  shuffle_questions: boolean;
  shuffle_options: boolean;
  allow_backtrack: boolean;
  show_results: boolean;
  proctoring: ProctoringConfig;
}

export interface CreateAssessmentResult {
  ok?: boolean;
  error?: string;
  id?: string;
}

export async function createAssessmentAction(input: CreateAssessmentInput): Promise<CreateAssessmentResult> {
  const result = await apiAction<{ id: string }>("POST", "/api/assessments", input);
  if (!result.ok) return { error: result.error };
  revalidatePath(ROUTES.MANAGE_ASSESSMENTS);
  return { ok: true, id: result.data?.id };
}

export async function addAssessmentQuestionAction(assessmentId: string, questionId: string, points?: number): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/assessments/${assessmentId}/questions`, { question_id: questionId, points });
  if (result.ok) revalidatePath(ROUTES.manageAssessment(assessmentId));
  return result;
}

export async function removeAssessmentQuestionAction(assessmentId: string, aqId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/assessments/${assessmentId}/questions/${aqId}`);
  if (result.ok) revalidatePath(ROUTES.manageAssessment(assessmentId));
  return result;
}

export async function publishAssessmentAction(assessmentId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/assessments/${assessmentId}/publish`);
  if (result.ok) revalidatePath(ROUTES.manageAssessment(assessmentId));
  return result;
}

export async function setAssessmentStatusAction(assessmentId: string, status: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/assessments/${assessmentId}/status`, { status });
  if (result.ok) revalidatePath(ROUTES.manageAssessment(assessmentId));
  return result;
}

export async function assignAssessmentAction(
  assessmentId: string,
  assigneeType: "student" | "batch",
  assigneeIds: string[],
): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/assessments/${assessmentId}/assignments`, {
    assignee_type: assigneeType,
    assignee_ids: assigneeIds,
  });
  if (result.ok) revalidatePath(ROUTES.manageAssessment(assessmentId));
  return result;
}
