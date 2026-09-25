"use server";

import { redirect } from "next/navigation";
import { apiAction } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export interface SaveStepState {
  error?: string;
  fieldErrors?: Record<string, string>;
}

async function patchOnboarding(
  orgId: string,
  data: Record<string, unknown>,
): Promise<{ ok: boolean; error?: string }> {
  const result = await apiAction("PATCH", `/api/orgs/${orgId}/onboarding`, data);
  if (!result.ok) {
    return { ok: false, error: result.error ?? "Something went wrong. Please try again." };
  }
  return { ok: true };
}

// ─── Step 1 — Identity (name, slug, description) ──────────────────────────────

export async function saveStep1Action(
  _prev: SaveStepState,
  formData: FormData,
): Promise<SaveStepState> {
  const orgId = (formData.get("org_id") ?? "").toString().trim();
  const name = (formData.get("name") ?? "").toString().trim();
  const slug = (formData.get("slug") ?? "").toString().trim();
  const description = (formData.get("description") ?? "").toString().trim();

  if (!orgId) return { error: "Organization ID is missing." };
  if (name.length < 2 || name.length > 100) {
    return { fieldErrors: { name: "Name must be between 2 and 100 characters." } };
  }

  const result = await patchOnboarding(orgId, {
    step: 1,
    name,
    slug: slug || undefined,
    description: description || null,
  });

  if (!result.ok) return { error: result.error };
  redirect(`${ROUTES.ORG_SETUP}?step=2`);
}

// ─── Step 2 — Authentication (allowed domains, SSO) ──────────────────────────

export async function saveStep2Action(
  _prev: SaveStepState,
  formData: FormData,
): Promise<SaveStepState> {
  const orgId = (formData.get("org_id") ?? "").toString().trim();
  const allowedDomains = (formData.get("allowed_domains") ?? "")
    .toString()
    .split(",")
    .map((d) => d.trim())
    .filter(Boolean);
  const ssoEnabled = formData.get("sso_enabled") === "true";

  if (!orgId) return { error: "Organization ID is missing." };

  const result = await patchOnboarding(orgId, {
    step: 2,
    allowed_domains: allowedDomains,
    sso_enabled: ssoEnabled,
  });

  if (!result.ok) return { error: result.error };
  redirect(`${ROUTES.ORG_SETUP}?step=3`);
}

// ─── Step 3 — Plan & Limits (seat limit) ─────────────────────────────────────

export async function saveStep3Action(
  _prev: SaveStepState,
  formData: FormData,
): Promise<SaveStepState> {
  const orgId = (formData.get("org_id") ?? "").toString().trim();
  const seatLimitRaw = (formData.get("seat_limit") ?? "").toString().trim();

  if (!orgId) return { error: "Organization ID is missing." };

  const seatLimit = seatLimitRaw ? parseInt(seatLimitRaw, 10) : null;
  if (seatLimit !== null && (isNaN(seatLimit) || seatLimit < 1)) {
    return { fieldErrors: { seat_limit: "Seat limit must be a positive number." } };
  }

  const result = await patchOnboarding(orgId, {
    step: 3,
    seat_limit: seatLimit,
  });

  if (!result.ok) return { error: result.error };
  redirect(`${ROUTES.ORG_SETUP}?step=4`);
}

// ─── Step 4 — Team (invite members) ──────────────────────────────────────────

export async function saveStep4Action(
  _prev: SaveStepState,
  formData: FormData,
): Promise<SaveStepState> {
  const orgId = (formData.get("org_id") ?? "").toString().trim();
  if (!orgId) return { error: "Organization ID is missing." };

  // Collect invite rows: invite_email_0, invite_role_0, invite_email_1, …
  const invites: { email: string; role: string }[] = [];
  let i = 0;
  while (formData.has(`invite_email_${i}`)) {
    const email = (formData.get(`invite_email_${i}`) ?? "").toString().trim();
    const role = (formData.get(`invite_role_${i}`) ?? "learner").toString();
    if (email) invites.push({ email, role });
    i++;
  }

  // Send each invite; collect errors
  const errors: string[] = [];
  for (const invite of invites) {
    const result = await apiAction("POST", `/api/orgs/${orgId}/invites`, invite);
    if (!result.ok) {
      errors.push(`${invite.email}: ${result.error ?? "failed"}`);
    }
  }

  if (errors.length > 0) {
    return { error: `Some invites could not be sent: ${errors.join("; ")}` };
  }

  // Mark onboarding step 4 complete
  const result = await patchOnboarding(orgId, { step: 4 });
  if (!result.ok) return { error: result.error };

  redirect(ROUTES.ORG_SETTINGS);
}

// ─── Activate org ─────────────────────────────────────────────────────────────

export async function activateOrgAction(
  _prev: SaveStepState,
  formData: FormData,
): Promise<SaveStepState> {
  const orgId = (formData.get("org_id") ?? "").toString().trim();
  if (!orgId) return { error: "Organization ID is missing." };

  const result = await apiAction("POST", `/api/orgs/${orgId}/activate`, {});
  if (!result.ok) {
    return { error: result.error ?? "Could not activate the organization. Please try again." };
  }

  redirect(ROUTES.ORG_SETTINGS);
}
