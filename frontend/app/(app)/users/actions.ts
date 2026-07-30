"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export async function updateUserStatusAction(
  orgId: string,
  memberId: string,
  status: "active" | "suspended",
): Promise<ActionResult> {
  const result = await apiAction("PATCH", `/api/orgs/${orgId}/members/${memberId}`, { status });
  if (result.ok) revalidatePath(ROUTES.USERS);
  return result;
}

export async function removeUserAction(orgId: string, memberId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/orgs/${orgId}/members/${memberId}`);
  if (result.ok) revalidatePath(ROUTES.USERS);
  return result;
}

// No bulk endpoint exists on the backend for member status/removal, so this
// fans out over the existing single-member endpoints — same permission
// checks, just N requests instead of one.
export async function bulkUpdateUserStatusAction(
  orgId: string,
  memberIds: string[],
  status: "active" | "suspended",
): Promise<ActionResult<{ failed: number }>> {
  const results = await Promise.all(
    memberIds.map((memberId) => apiAction("PATCH", `/api/orgs/${orgId}/members/${memberId}`, { status })),
  );
  const failed = results.filter((r) => !r.ok).length;
  if (failed < results.length) revalidatePath(ROUTES.USERS);
  if (failed > 0) return { error: `${failed} of ${memberIds.length} update(s) failed.`, data: { failed } };
  return { ok: true, data: { failed: 0 } };
}

export async function bulkRemoveUsersAction(
  orgId: string,
  memberIds: string[],
): Promise<ActionResult<{ failed: number }>> {
  const results = await Promise.all(
    memberIds.map((memberId) => apiAction("DELETE", `/api/orgs/${orgId}/members/${memberId}`)),
  );
  const failed = results.filter((r) => !r.ok).length;
  if (failed < results.length) revalidatePath(ROUTES.USERS);
  if (failed > 0) return { error: `${failed} of ${memberIds.length} removal(s) failed.`, data: { failed } };
  return { ok: true, data: { failed: 0 } };
}

// Re-triggers the same self-service "forgot password" email flow on the
// user's behalf — the admin never sees or sets the password itself.
export async function resetUserPasswordAction(email: string): Promise<ActionResult> {
  return apiAction("POST", "/api/auth/forgot-password", { email });
}
