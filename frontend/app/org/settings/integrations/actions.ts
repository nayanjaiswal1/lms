"use server";

import { revalidatePath } from "next/cache";
import { authHeaders, baseURL } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export interface AIConnectorConfigActionState {
  error?: string;
}

export async function saveAIConnectorConfigAction(
  prev: AIConnectorConfigActionState,
  formData: FormData,
): Promise<AIConnectorConfigActionState> {
  const orgId = formData.get("org_id") as string | null;
  const enabled = formData.get("enabled") === "true";

  if (!orgId) return { error: "Missing organisation ID." };

  const headers = await authHeaders();
  const res = await fetch(`${baseURL()}/api/orgs/${orgId}/ai-connector-config`, {
    method: "PATCH",
    headers,
    body: JSON.stringify({ enabled }),
  });

  if (!res.ok) {
    const parsed = await res.json().catch(() => null) as { error?: string } | null;
    return { error: parsed?.error ?? "Failed to save AI connector configuration." };
  }

  revalidatePath(ROUTES.ORG_SETTINGS_INTEGRATIONS);
  return {};
}
