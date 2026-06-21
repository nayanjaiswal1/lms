"use server";

import { revalidatePath } from "next/cache";
import { authHeaders, baseURL } from "@/lib/server/api";
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

  const headers = await authHeaders();
  const res = await fetch(`${baseURL()}/api/orgs/${orgId}/domains`, {
    method: "POST",
    headers,
    body: JSON.stringify({ domain, verification_method: verificationMethod ?? "dns_txt" }),
  });

  if (!res.ok) {
    const parsed = await res.json().catch(() => null) as { error?: string } | null;
    return { error: parsed?.error ?? "Failed to add domain." };
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

  const headers = await authHeaders();
  const res = await fetch(`${baseURL()}/api/orgs/${orgId}/domains/verify`, {
    method: "POST",
    headers,
    body: JSON.stringify({ domain_id: domainId }),
  });

  if (!res.ok) {
    const parsed = await res.json().catch(() => null) as { error?: string } | null;
    return { error: parsed?.error ?? "Verification failed. Ensure the DNS record is set." };
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

  const headers = await authHeaders();
  const res = await fetch(
    `${baseURL()}/api/orgs/${orgId}/domains/${domainId}/auto-join`,
    {
      method: "POST",
      headers,
      body: JSON.stringify({ enabled }),
    },
  );

  if (!res.ok) {
    const parsed = await res.json().catch(() => null) as { error?: string } | null;
    return { error: parsed?.error ?? "Failed to update auto-join setting." };
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

  const headers = await authHeaders();
  const res = await fetch(`${baseURL()}/api/orgs/${orgId}/domains/${domainId}`, {
    method: "DELETE",
    headers,
  });

  if (!res.ok) {
    const parsed = await res.json().catch(() => null) as { error?: string } | null;
    return { error: parsed?.error ?? "Failed to remove domain." };
  }

  revalidatePath(ROUTES.ORG_SETTINGS_DOMAINS);
  return {};
}
