"use server";

import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";

interface BatchCreateResult {
  queued: number;
  job_count: number;
  skipped: Array<{ email: string; reason: string }>;
}

export async function batchInviteAction(
  orgId: string,
  emails: string[],
  role: string,
): Promise<ActionResult<BatchCreateResult>> {
  return apiAction("POST", `/api/orgs/${orgId}/invites/batch`, { emails, role });
}

export async function batchRevokeAction(
  orgId: string,
  inviteIds: string[],
): Promise<ActionResult<{ revoked: number }>> {
  return apiAction("DELETE", `/api/orgs/${orgId}/invites/batch`, {
    invite_ids: inviteIds,
  });
}

export async function batchResendAction(
  orgId: string,
  inviteIds: string[],
): Promise<ActionResult<{ resent_count: number }>> {
  return apiAction("POST", `/api/orgs/${orgId}/invites/batch/resend`, {
    invite_ids: inviteIds,
  });
}

export async function revokeInviteAction(
  orgId: string,
  inviteId: string,
): Promise<ActionResult> {
  return apiAction("DELETE", `/api/orgs/${orgId}/invites/${inviteId}`);
}
