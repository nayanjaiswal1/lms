"use server";

import { revalidatePath } from "next/cache";
import { apiAction, ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export type { ActionResult };

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
  if (result.ok) revalidatePath(ROUTES.MENTORING_BATCHES);
  return result;
}
