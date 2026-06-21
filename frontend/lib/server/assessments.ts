import "server-only";

import { apiGet, apiPost } from "@/lib/server/api";
import type {
  AssignedAssessment,
  Assessment,
  Question,
  AttemptPayload,
  ReviewItem,
  Attempt,
  AssessmentAnalytics,
  AttemptRow,
  Batch,
  EvaluationStatus,
  FullEvaluation,
  StudentProgress,
  SkillTrend,
  ReviewQueueItem,
} from "@/lib/assessments/types";

// ─── Student reads ───────────────────────────────────────────────────────────

export async function getMyAssessments(): Promise<AssignedAssessment[]> {
  const data = await apiGet<{ assessments: AssignedAssessment[] }>("/api/my/assessments");
  return data.assessments;
}

export async function getAttemptResult(
  attemptId: string,
): Promise<{ attempt: Attempt; show_review: boolean; review?: ReviewItem[] }> {
  return apiGet(`/api/attempts/${attemptId}/result`);
}

export async function getMyAnalytics(): Promise<{
  completed: number;
  passed: number;
  avg_percentage: number;
  total_time_sec: number;
}> {
  return apiGet("/api/my/analytics");
}

// ─── Staff reads ─────────────────────────────────────────────────────────────

export async function getAssessments(query = ""): Promise<Assessment[]> {
  const data = await apiGet<{ assessments: Assessment[] }>(`/api/assessments${query}`);
  return data.assessments;
}

export async function getAssessment(
  id: string,
): Promise<{ assessment: Assessment; questions: AssessmentQuestionFull[] }> {
  return apiGet(`/api/assessments/${id}`);
}

export interface AssessmentQuestionFull {
  id: string;
  question_id: string;
  position: number;
  points: number;
  type: "mcq" | "coding";
  title: string;
  difficulty: string;
  content: unknown;
}

export async function getQuestions(query = ""): Promise<{ questions: Question[]; total: number }> {
  return apiGet(`/api/questions${query}`);
}

export async function getBatches(): Promise<Batch[]> {
  const data = await apiGet<{ batches: Batch[] }>("/api/batches");
  return data.batches;
}

export async function getAssessmentAnalytics(id: string): Promise<AssessmentAnalytics> {
  return apiGet(`/api/assessments/${id}/analytics`);
}

export async function getAssessmentAttempts(id: string): Promise<AttemptRow[]> {
  const data = await apiGet<{ attempts: AttemptRow[] }>(`/api/assessments/${id}/attempts`);
  return data.attempts;
}

export async function getOrgAnalytics(): Promise<{
  total_assessments: number;
  total_questions: number;
  total_attempts: number;
  avg_pass_rate: number;
  active_batches: number;
}> {
  return apiGet("/api/analytics/overview");
}

// startAttempt is a POST but is invoked from a server component on the take page
// to obtain the question set, so it lives with the server reads.
export async function startAttempt(assessmentId: string): Promise<AttemptPayload> {
  return apiPost<AttemptPayload>(`/api/assessments/${assessmentId}/attempts`);
}

// ─── Interview evaluation ─────────────────────────────────────────────────────

export async function getEvaluationStatus(attemptId: string): Promise<EvaluationStatus> {
  return apiGet(`/api/attempts/${attemptId}/evaluation/status`);
}

export async function getEvaluation(attemptId: string): Promise<FullEvaluation> {
  return apiGet(`/api/attempts/${attemptId}/evaluation`);
}

export async function getStudentProgress(): Promise<StudentProgress> {
  return apiGet("/api/interview/progress");
}

export async function getSkillTrends(): Promise<{ skill_trends: SkillTrend[] }> {
  return apiGet("/api/interview/skills");
}

export async function getReviewQueue(
  limit = 50,
  offset = 0,
): Promise<{ items: ReviewQueueItem[] }> {
  return apiGet(`/api/interview/review-queue?limit=${limit}&offset=${offset}`);
}
