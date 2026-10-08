"use server";

import { redirect } from "next/navigation";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

/** Accepts a batch invitation, then lets the user pick the (possibly new) org. */
export async function acceptBatchInvitationAction(token: string): Promise<ActionResult> {
  const result = await apiAction("POST", "/api/invitations/accept", { token });
  if (result.error) return result;
  redirect(ROUTES.ORG_SELECT);
}

export async function declineBatchInvitationAction(token: string): Promise<ActionResult> {
  return apiAction("POST", "/api/invitations/decline", { token });
}
