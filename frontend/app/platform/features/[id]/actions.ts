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
