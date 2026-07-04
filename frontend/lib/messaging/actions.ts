"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import { getSimilarFAQs, type SimilarFAQ } from "@/lib/server/messaging";

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

export async function askQuestionAction(batchId: string, body: string): Promise<ActionResult<{ id: string }>> {
  return apiAction<{ id: string }>("POST", `/api/batches/${batchId}/messages`, {
    body,
    type: "question",
  });
}

// Thin server-action wrapper: client components cannot call "server-only"
// read helpers directly, so this bridges the client-side debounced search
// in ask-question.tsx to lib/server/messaging.ts's getSimilarFAQs.
export async function getSimilarFAQsAction(
  courseId: string,
  q: string,
): Promise<ActionResult<{ faqs: SimilarFAQ[] }>> {
  try {
    const faqs = await getSimilarFAQs(courseId, q);
    return { ok: true, data: { faqs } };
  } catch {
    return { error: "Failed to load similar questions." };
  }
}
