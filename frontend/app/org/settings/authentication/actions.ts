"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export interface AuthConfigActionState {
  error?: string;
}

export async function saveAuthConfigAction(
  prev: AuthConfigActionState,
  formData: FormData,
): Promise<AuthConfigActionState> {
  const orgId = formData.get("org_id") as string | null;
  const ssoEnabled = formData.get("sso_enabled") === "true";
  const ssoProvider = formData.get("sso_provider") as string | null;

  if (!orgId) return { error: "Missing organisation ID." };

  const payload: Record<string, unknown> = {
    sso_enabled: ssoEnabled,
  };
  if (ssoEnabled && ssoProvider) {
    payload.sso_provider = ssoProvider;
  } else {
    payload.sso_provider = null;
  }

  const result = await apiAction("PATCH", `/api/orgs/${orgId}/auth-config`, payload);
  if (!result.ok) {
    return { error: result.error ?? "Failed to save authentication configuration." };
  }

  revalidatePath(ROUTES.ORG_SETTINGS_AUTH);
  return {};
}
