import { cache } from "react";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { notFound } from "next/navigation";
import { type Feature, type LockedFeatureInfo } from "@/lib/features";
import ROUTES from "@/lib/routes";

// ─────────────────────────────────────────────
// What the backend returns for /api/me/features
//
// orgFeatures  — features the org admin has turned on
// entitlements — features this specific user can actually use
//               (resolved from org plan + user add-ons + org grants)
// lockedInfo   — for each org-enabled but non-entitled feature,
//               how to unlock it (plan / addon / plan_or_addon)
// ─────────────────────────────────────────────

export interface FeatureConfig {
  orgFeatures:  Feature[];
  entitlements: Feature[];
  lockedInfo:   Partial<Record<Feature, LockedFeatureInfo>>;
}

const EMPTY_CONFIG: FeatureConfig = { orgFeatures: [], entitlements: [], lockedInfo: {} };

/**
 * Fetch the full feature config for the current user + org.
 * Called once in root layout and reused by every server guard below.
 *
 * Wrapped in React `cache()` so all calls within a single request render hit
 * the backend exactly once (layout + every requireAccess guard share one fetch).
 *
 * `cache: "no-store"` is deliberate: this payload is per-user. Putting it in
 * Next's shared Data Cache (which keys on URL, not the Cookie header) would let
 * one user's entitlements be served to another within the cache window.
 * Per-request dedup via cache() gives the perf win without the cross-user leak.
 *
 * The backend handles all resolution logic:
 *   entitlements = org_plan_features ∪ user_addons ∪ org_granted_features
 * The frontend never re-derives this — it trusts the entitlements list.
 */
export const getFeatureConfig = cache(async (): Promise<FeatureConfig> => {
  const cookieStore = await cookies();
  const token = cookieStore.get("access_token")?.value;

  if (!token) return EMPTY_CONFIG;

  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) {
    console.error("[features] BACKEND_URL is not set — feature config unavailable");
    return EMPTY_CONFIG;
  }

  try {
    const res = await fetch(`${apiUrl}/api/me/features`, {
      headers: { Cookie: `access_token=${token}` },
      cache: "no-store",
    });

    if (!res.ok) return EMPTY_CONFIG;

    return (await res.json()) as FeatureConfig;
  } catch {
    return EMPTY_CONFIG;
  }
});

// ─────────────────────────────────────────────
// Server-side guards — use at the top of page.tsx
// These run before any rendering, so users get a
// 404 or redirect before the page shell loads.
// ─────────────────────────────────────────────

/**
 * 404 if the org has not enabled this feature.
 * Use when the feature simply does not exist for this org.
 */
export async function requireOrgFeature(feature: Feature): Promise<void> {
  const { orgFeatures } = await getFeatureConfig();
  if (!orgFeatures.includes(feature)) notFound();
}

/**
 * Redirect to billing if the user is not entitled to this feature.
 * Entitlement = plan + add-ons, resolved server-side.
 * Use when the feature exists for the org but the user hasn't unlocked it.
 */
export async function requireEntitlement(feature: Feature): Promise<void> {
  const { entitlements } = await getFeatureConfig();
  if (!entitlements.includes(feature)) {
    redirect(`${ROUTES.BILLING}?feature=${feature}`);
  }
}

/**
 * Combines both checks: org must have the feature enabled
 * AND the user must have an entitlement.
 * This is the most common guard for feature pages.
 */
export async function requireAccess(feature: Feature): Promise<void> {
  const { orgFeatures, entitlements } = await getFeatureConfig();
  if (!orgFeatures.includes(feature)) notFound();
  if (!entitlements.includes(feature)) redirect(`${ROUTES.BILLING}?feature=${feature}`);
}
