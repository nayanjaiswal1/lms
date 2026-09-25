import "server-only";

import { apiGet, baseURL } from "@/lib/server/api";

export interface PricingTier {
  id: string;
  audience: "individual" | "org";
  position: number;
  name: string;
  price: string;
  billing_note: string;
  tagline: string;
  features: string[];
  cta_label: string;
  cta_disabled: boolean;
  cta_href?: string;
  highlighted: boolean;
  updated_at: string;
}

/** One landing page's pricing section — audience is required, there is no "both" case for a single page. */
// Anonymous + identical for every visitor, so it rides the Data Cache instead of
// a no-store backend round trip on every landing-page view. Admin edits in
// app/platform/pricing/actions.ts revalidatePath the pages that read this.
export async function getPublicPricingTiers(audience: "individual" | "org"): Promise<PricingTier[]> {
  const res = await fetch(`${baseURL()}/api/public/pricing?audience=${audience}`, {
    next: { revalidate: 60 },
  });
  if (!res.ok) throw new Error(`GET /api/public/pricing failed: ${res.status}`);
  const body = (await res.json()) as { data: { tiers: PricingTier[] } };
  return body.data.tiers;
}

/** Every tier across both audiences, for the /platform/pricing admin page. */
export async function getAdminPricingTiers(): Promise<PricingTier[]> {
  const { tiers } = await apiGet<{ tiers: PricingTier[] }>("/api/admin/pricing");
  return tiers;
}
