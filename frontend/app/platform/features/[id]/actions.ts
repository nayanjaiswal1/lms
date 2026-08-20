"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export async function setOrgFeatureFlagAction(
  orgId: string,
  key: string,
  enabled: boolean,
): Promise<ActionResult> {
  const result = await apiAction("PATCH", `/api/admin/orgs/${orgId}/feature-flags/${key}`, { enabled });
  if (result.ok) revalidatePath(ROUTES.platformOrgFeatures(orgId));
  return result;
}

export async function clearOrgFeatureFlagAction(
  orgId: string,
  key: string,
): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/admin/orgs/${orgId}/feature-flags/${key}`);
  if (result.ok) revalidatePath(ROUTES.platformOrgFeatures(orgId));
  return result;
}

/** Moves orgId onto a different pricing tier — see backend/internal/entitlements. */
export async function setOrgTierAction(orgId: string, tierId: string): Promise<ActionResult> {
  const result = await apiAction("PUT", `/api/admin/orgs/${orgId}/tier`, { tier_id: tierId });
  if (result.ok) revalidatePath(ROUTES.platformOrgFeatures(orgId));
  return result;
}
