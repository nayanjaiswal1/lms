"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { Comment, CreatePostInput, Entry, FaqStatus, Post, Qna } from "@/lib/server/interview-exp";

export async function createPostAction(input: CreatePostInput): Promise<ActionResult<Post>> {
  return apiAction<Post>("POST", "/api/interview-exp/posts", input);
}

export async function createEntryAction(
  postId: string,
  input: { round_label: string; content: string },
): Promise<ActionResult<Entry>> {
  const result = await apiAction<Entry>("POST", `/api/interview-exp/posts/${postId}/entries`, input);
  if (result.ok) revalidatePath(ROUTES.INTERVIEW_EXP, "layout");
  return result;
}

export async function createStandaloneQnaAction(
  postId: string,
  input: { question: string; answer?: string },
): Promise<ActionResult<Qna>> {
  const result = await apiAction<Qna>("POST", `/api/interview-exp/posts/${postId}/qna`, input);
  if (result.ok) revalidatePath(ROUTES.INTERVIEW_EXP, "layout");
  return result;
}

export async function createEntryQnaAction(
  entryId: string,
  input: { question: string; answer?: string },
): Promise<ActionResult<Qna>> {
  const result = await apiAction<Qna>("POST", `/api/interview-exp/entries/${entryId}/qna`, input);
  if (result.ok) revalidatePath(ROUTES.INTERVIEW_EXP, "layout");
  return result;
}

export async function createCommentAction(
  qnaId: string,
  input: { content: string; parent_id?: string },
): Promise<ActionResult<Comment>> {
  const result = await apiAction<Comment>("POST", `/api/interview-exp/qna/${qnaId}/comments`, input);
  if (result.ok) revalidatePath(ROUTES.INTERVIEW_EXP, "layout");
  return result;
}

export async function voteAction(
  targetType: "qna" | "comment",
  targetId: string,
  value: -1 | 0 | 1,
): Promise<ActionResult> {
  const result = await apiAction("POST", "/api/interview-exp/vote", { target_type: targetType, target_id: targetId, value });
  if (result.ok) revalidatePath(ROUTES.INTERVIEW_EXP, "layout");
  return result;
}

export async function updateFaqStatusAction(qnaId: string, status: FaqStatus): Promise<ActionResult> {
  const result = await apiAction("PATCH", `/api/interview-exp/faq/${qnaId}/progress`, { status });
  if (result.ok) revalidatePath(ROUTES.INTERVIEW_EXP_FAQ, "page");
  return result;
}

export async function updateFaqStarredAction(qnaId: string, starred: boolean): Promise<ActionResult> {
  const result = await apiAction("PATCH", `/api/interview-exp/faq/${qnaId}/star`, { starred });
  if (result.ok) revalidatePath(ROUTES.INTERVIEW_EXP_FAQ, "page");
  return result;
}
