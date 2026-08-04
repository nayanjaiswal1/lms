"use server";

import { revalidatePath } from "next/cache";
import { apiAction, apiUpload, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export async function updateOrgTypeAction(orgId: string, orgType: string): Promise<ActionResult> {
  const res = await apiAction("PATCH", `/api/orgs/${orgId}`, { org_type: orgType });
  if (res.ok) revalidatePath(ROUTES.ORG_SETTINGS);
  return res;
}

export async function updateOrgBrandingAction(
  orgId: string,
  branding: { name: string; logo_url: string | null },
): Promise<ActionResult> {
  const res = await apiAction("PATCH", `/api/orgs/${orgId}`, branding);
  if (res.ok) revalidatePath(ROUTES.ORG_SETTINGS);
  return res;
}

export async function uploadOrgLogoAction(
  formData: FormData,
): Promise<ActionResult<{ url: string; storage_key: string }>> {
  return apiUpload<{ url: string; storage_key: string }>("/api/upload", formData);
}
