"use server";

import { revalidatePath } from "next/cache";
import { apiAction, authHeaders, baseURL, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { BatchInviteResult } from "@/lib/orgs/types";

export interface MemberActionState {
  error?: string;
}

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

// Locks or restores the platform ACCOUNT, which is a different thing from the
// org-membership suspend above: updateUserStatusAction only removes access to
// this organization, while this refuses every sign-in path platform-wide and
// kills the user's live sessions. Distinct endpoint, distinct wording in the UI.
export async function setAccountStatusAction(
  userId: string,
  status: "active" | "suspended" | "deactivated",
  reason?: string,
): Promise<ActionResult> {
  const result = await apiAction("PATCH", `/api/admin/rbac/users/${userId}/status`, {
    status,
    reason: reason ?? "",
  });
  if (result.ok) revalidatePath(ROUTES.USERS);
  return result;
}

// Re-triggers the same self-service "forgot password" email flow on the
// user's behalf — the admin never sees or sets the password itself.
export async function resetUserPasswordAction(email: string): Promise<ActionResult> {
  return apiAction("POST", "/api/auth/forgot-password", { email });
}

// ─── Org role / invites (MANAGE_ORG) ───────────────────────────────────────
// Distinct from the org-membership suspend/remove above (MANAGE_MEMBERS):
// these cover the coarse owner/admin/instructor/mentor/learner role, and
// bringing new people into the org in the first place.

export async function updateMemberAction(
  prev: MemberActionState,
  formData: FormData,
): Promise<MemberActionState> {
  const orgId = formData.get("org_id") as string | null;
  const memberId = formData.get("member_id") as string | null;
  const role = formData.get("role") as string | null;
  const status = formData.get("status") as string | null;

  if (!orgId || !memberId) return { error: "Missing required fields." };

  const body: Record<string, string> = {};
  if (role) body.role = role;
  if (status) body.status = status;

  const headers = await authHeaders();
  const res = await fetch(`${baseURL()}/api/orgs/${orgId}/members/${memberId}`, {
    method: "PATCH",
    headers,
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const parsed = await res.json().catch(() => null) as { error?: string } | null;
    return { error: parsed?.error ?? "Failed to update member." };
  }

  revalidatePath(ROUTES.USERS);
  return {};
}

export async function revokeInviteAction(
  prev: MemberActionState,
  formData: FormData,
): Promise<MemberActionState> {
  const orgId = formData.get("org_id") as string | null;
  const inviteId = formData.get("invite_id") as string | null;

  if (!orgId || !inviteId) return { error: "Missing required fields." };

  const headers = await authHeaders();
  const res = await fetch(`${baseURL()}/api/orgs/${orgId}/invites/${inviteId}`, {
    method: "DELETE",
    headers,
  });

  if (!res.ok) {
    const parsed = await res.json().catch(() => null) as { error?: string } | null;
    return { error: parsed?.error ?? "Failed to revoke invite." };
  }

  revalidatePath(ROUTES.USERS);
  return {};
}

export async function resendInviteAction(orgId: string, inviteId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/orgs/${orgId}/invites/${inviteId}/resend`);
  if (result.ok) revalidatePath(ROUTES.USERS);
  return result;
}

// Queues one org invite per email (async, emailed in the background — see
// invite.bulk job handler) instead of the single-invite round trip above.
// `skipped` reports emails the backend rejected up front (bad format,
// already invited, already a member) so the caller can surface them inline.
export async function bulkCreateInvitesAction(
  orgId: string,
  emails: string[],
  role: string,
): Promise<ActionResult<BatchInviteResult>> {
  const result = await apiAction<BatchInviteResult>("POST", `/api/orgs/${orgId}/invites/batch`, { emails, role });
  if (result.ok) revalidatePath(ROUTES.USERS);
  return result;
}
