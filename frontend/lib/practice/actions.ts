"use server";

import { revalidatePath } from "next/cache";
import { apiAction, ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export type { ActionResult };

export async function createSessionAction(input: {
  technology: string;
  difficulty: string;
  question_count: number;
}): Promise<ActionResult<{ id: string }>> {
  const result = await apiAction<{ id: string }>("POST", "/api/practice/sessions", input);
  if (result.ok) revalidatePath(ROUTES.PRACTICE);
  return result;
}

export async function submitAnswerAction(
  sessionId: string,
  position: number,
  answerText: string,
): Promise<ActionResult<unknown>> {
  const result = await apiAction<unknown>(
    "POST",
    `/api/practice/sessions/${sessionId}/items/${position}/answer`,
    { answer_text: answerText },
  );
  if (result.ok) revalidatePath(ROUTES.practiceSession(sessionId));
  return result;
}
