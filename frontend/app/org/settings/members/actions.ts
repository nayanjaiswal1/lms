"use server";

import { revalidatePath } from "next/cache";
import { authHeaders, baseURL } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export interface MemberActionState {
  error?: string;
}

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

  revalidatePath(ROUTES.ORG_SETTINGS_MEMBERS);
  return {};
}

export async function removeMemberAction(
  prev: MemberActionState,
  formData: FormData,
): Promise<MemberActionState> {
  const orgId = formData.get("org_id") as string | null;
  const memberId = formData.get("member_id") as string | null;

  if (!orgId || !memberId) return { error: "Missing required fields." };

  const headers = await authHeaders();
  const res = await fetch(`${baseURL()}/api/orgs/${orgId}/members/${memberId}`, {
    method: "DELETE",
    headers,
  });

  if (!res.ok) {
    const parsed = await res.json().catch(() => null) as { error?: string } | null;
    return { error: parsed?.error ?? "Failed to remove member." };
  }

  revalidatePath(ROUTES.ORG_SETTINGS_MEMBERS);
  return {};
}

export async function createInviteAction(
  prev: MemberActionState,
  formData: FormData,
): Promise<MemberActionState> {
  const orgId = formData.get("org_id") as string | null;
  const email = formData.get("email") as string | null;
  const role = formData.get("role") as string | null;

  if (!orgId || !email || !role) return { error: "Email and role are required." };

  const headers = await authHeaders();
  const res = await fetch(`${baseURL()}/api/orgs/${orgId}/invites`, {
    method: "POST",
    headers,
    body: JSON.stringify({ email, role }),
  });

  if (!res.ok) {
    const parsed = await res.json().catch(() => null) as { error?: string } | null;
    return { error: parsed?.error ?? "Failed to send invite." };
  }

  revalidatePath(ROUTES.ORG_SETTINGS_MEMBERS);
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

  revalidatePath(ROUTES.ORG_SETTINGS_MEMBERS);
  return {};
}
