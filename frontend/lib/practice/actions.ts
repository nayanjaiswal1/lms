"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

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
