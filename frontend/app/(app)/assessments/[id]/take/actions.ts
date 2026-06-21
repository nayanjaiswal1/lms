"use server";

import { apiAction } from "@/lib/server/api";

export interface ActionResult {
  ok: boolean;
  error?: string;
}

// saveAnswerAction persists a draft answer mid-attempt. Fire-and-forget from the
// client; failures surface only as a non-blocking toast. Pass transcript for
// subjective questions instead of (or alongside) answer.
export async function saveAnswerAction(
  attemptId: string,
  assessmentQuestionId: string,
  answer: unknown,
  timeSpentSeconds: number,
  transcript?: string,
): Promise<ActionResult> {
  const result = await apiAction("PUT", `/api/attempts/${attemptId}/answers`, {
    assessment_question_id: assessmentQuestionId,
    answer,
    transcript: transcript ?? null,
    time_spent_seconds: timeSpentSeconds,
  });
  return { ok: !!result.ok, error: result.error };
}

// recordEventAction reports a proctoring signal. Returns auto_submitted=true when
// the server force-submitted the attempt due to a breached threshold.
export async function recordEventAction(
  attemptId: string,
  eventType: string,
  severity: "info" | "warning" | "critical",
  metadata: Record<string, unknown>,
): Promise<{ ok: boolean; autoSubmitted: boolean }> {
  const result = await apiAction<{ auto_submitted?: boolean }>("POST", `/api/attempts/${attemptId}/events`, {
    event_type: eventType,
    severity,
    metadata,
    client_ts: new Date().toISOString(),
  });
  return { ok: !!result.ok, autoSubmitted: Boolean(result.data?.auto_submitted) };
}

// submitAttemptAction grades and finalizes the attempt.
export async function submitAttemptAction(attemptId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/attempts/${attemptId}/submit`);
  return { ok: !!result.ok, error: result.error };
}
