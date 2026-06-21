"use server";

import { revalidatePath } from "next/cache";
import { apiAction, ActionResult } from "@/lib/server/api";

export type { ActionResult };

export async function postMessageAction(
  batchId: string,
  input: { body: string; type?: string; parent_id?: string },
): Promise<ActionResult<{ id: string }>> {
  const result = await apiAction<{ id: string }>("POST", `/api/batches/${batchId}/messages`, input);
  if (result.ok) revalidatePath(`/mentor/batches/${batchId}/chat`);
  return result;
}

export async function resolveMessageAction(msgId: string, batchId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/messages/${msgId}/resolve`);
  if (result.ok) revalidatePath(`/mentor/batches/${batchId}/chat`);
  return result;
}

export async function promoteFAQAction(
  msgId: string,
  input: { course_id: string; question: string; answer: string },
): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/messages/${msgId}/promote-faq`, input);
  if (result.ok) revalidatePath(`/courses/${input.course_id}`);
  return result;
}
