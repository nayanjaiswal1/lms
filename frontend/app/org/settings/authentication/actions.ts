"use server";

import { revalidatePath } from "next/cache";
import { authHeaders, baseURL } from "@/lib/server/api";
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

  const headers = await authHeaders();
  const res = await fetch(`${baseURL()}/api/orgs/${orgId}/auth-config`, {
    method: "PATCH",
    headers,
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const parsed = await res.json().catch(() => null) as { error?: string } | null;
    return { error: parsed?.error ?? "Failed to save authentication configuration." };
  }

  revalidatePath(ROUTES.ORG_SETTINGS_AUTH);
  return {};
}
