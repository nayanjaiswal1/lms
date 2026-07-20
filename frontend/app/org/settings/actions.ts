"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export async function updateOrgTypeAction(orgId: string, orgType: string): Promise<ActionResult> {
  const res = await apiAction("PATCH", `/api/orgs/${orgId}`, { org_type: orgType });
  if (res.ok) revalidatePath(ROUTES.ORG_SETTINGS);
  return res;
}
