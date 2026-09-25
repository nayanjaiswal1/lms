"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export interface DomainActionState {
  error?: string;
}

export async function addDomainAction(
  prev: DomainActionState,
  formData: FormData,
): Promise<DomainActionState> {
  const orgId = formData.get("org_id") as string | null;
  const domain = formData.get("domain") as string | null;
  const verificationMethod = formData.get("verification_method") as string | null;

  if (!orgId || !domain) return { error: "Domain is required." };

  const addResult = await apiAction("POST", `/api/orgs/${orgId}/domains`, {
    domain,
    verification_method: verificationMethod ?? "dns_txt",
  });
  if (!addResult.ok) {
    return { error: addResult.error ?? "Failed to add domain." };
  }

  revalidatePath(ROUTES.ORG_SETTINGS_DOMAINS);
  return {};
}

export async function verifyDomainAction(
  prev: DomainActionState,
  formData: FormData,
): Promise<DomainActionState> {
  const orgId = formData.get("org_id") as string | null;
  const domainId = formData.get("domain_id") as string | null;

  if (!orgId || !domainId) return { error: "Missing required fields." };

  const verifyResult = await apiAction("POST", `/api/orgs/${orgId}/domains/verify`, {
    domain_id: domainId,
  });
  if (!verifyResult.ok) {
    return { error: verifyResult.error ?? "Verification failed. Ensure the DNS record is set." };
  }

  revalidatePath(ROUTES.ORG_SETTINGS_DOMAINS);
  return {};
}

export async function toggleAutoJoinAction(
  prev: DomainActionState,
  formData: FormData,
): Promise<DomainActionState> {
  const orgId = formData.get("org_id") as string | null;
  const domainId = formData.get("domain_id") as string | null;
  const enabled = formData.get("enabled") === "true";

  if (!orgId || !domainId) return { error: "Missing required fields." };

  const toggleResult = await apiAction("POST", `/api/orgs/${orgId}/domains/${domainId}/auto-join`, {
    enabled,
  });
  if (!toggleResult.ok) {
    return { error: toggleResult.error ?? "Failed to update auto-join setting." };
  }

  revalidatePath(ROUTES.ORG_SETTINGS_DOMAINS);
  return {};
}

export async function removeDomainAction(
  prev: DomainActionState,
  formData: FormData,
): Promise<DomainActionState> {
  const orgId = formData.get("org_id") as string | null;
  const domainId = formData.get("domain_id") as string | null;

  if (!orgId || !domainId) return { error: "Missing required fields." };

  const removeResult = await apiAction("DELETE", `/api/orgs/${orgId}/domains/${domainId}`);
  if (!removeResult.ok) {
    return { error: removeResult.error ?? "Failed to remove domain." };
  }

  revalidatePath(ROUTES.ORG_SETTINGS_DOMAINS);
  return {};
}
