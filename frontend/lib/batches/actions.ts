"use server";

import { revalidatePath } from "next/cache";
import { apiAction, apiUpload, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export interface InvitationToken {
  email: string;
  token: string;
}

export async function inviteMembersAction(
  batchId: string,
  emails: string[],
): Promise<ActionResult<{ invited: number; tokens: InvitationToken[] }>> {
  const result = await apiAction<{ invited: number; tokens: InvitationToken[] }>(
    "POST",
    `/api/batches/${batchId}/invite`,
    { emails },
  );
  if (result.ok) revalidatePath(ROUTES.BATCHES);
  return result;
}

export async function acceptInvitationAction(
  token: string,
): Promise<ActionResult<{ batch_id: string; org_id: string }>> {
  return apiAction<{ batch_id: string; org_id: string }>("POST", "/api/invitations/accept", { token });
}

export async function assignCourseAction(batchId: string, courseId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/batches/${batchId}/courses`, { course_id: courseId });
  if (result.ok) revalidatePath(`${ROUTES.batch(batchId)}/courses`);
  return result;
}

export async function unassignCourseAction(batchId: string, courseId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/batches/${batchId}/courses/${courseId}`);
  if (result.ok) revalidatePath(`${ROUTES.batch(batchId)}/courses`);
  return result;
}

export async function addBatchMentorAction(batchId: string, userId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/batches/${batchId}/mentors`, { user_id: userId });
  if (result.ok) revalidatePath(`${ROUTES.batch(batchId)}/mentors`);
  return result;
}

export async function removeBatchMentorAction(batchId: string, userId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/batches/${batchId}/mentors/${userId}`);
  if (result.ok) revalidatePath(`${ROUTES.batch(batchId)}/mentors`);
  return result;
}

export async function resendInvitationAction(
  batchId: string,
  invitationId: string,
): Promise<ActionResult<InvitationToken>> {
  const result = await apiAction<InvitationToken>(
    "POST",
    `/api/batches/${batchId}/invitations/${invitationId}/resend`,
  );
  if (result.ok) revalidatePath(ROUTES.batch(batchId));
  return result;
}

export async function revokeInvitationAction(batchId: string, invitationId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/batches/${batchId}/invitations/${invitationId}`);
  if (result.ok) revalidatePath(ROUTES.batch(batchId));
  return result;
}

export async function uploadBatchImageAction(
  batchId: string,
  formData: FormData,
): Promise<ActionResult<{ image_url: string }>> {
  const file = formData.get("avatar") as File | null;
  if (!file) return { error: "No image selected." };

  const body = new FormData();
  body.append("image", file);

  const result = await apiUpload<{ image_url: string }>(`/api/batches/${batchId}/image`, body);
  if (!result.ok) return { error: result.error ?? "Failed to upload image." };
  revalidatePath(ROUTES.BATCHES);
  revalidatePath(ROUTES.batch(batchId));
  return { ok: true, data: result.data };
}

export async function deleteBatchImageAction(batchId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/batches/${batchId}/image`);
  if (result.ok) {
    revalidatePath(ROUTES.BATCHES);
    revalidatePath(ROUTES.batch(batchId));
    revalidatePath(ROUTES.BATCHES);
  }
  return result;
}
