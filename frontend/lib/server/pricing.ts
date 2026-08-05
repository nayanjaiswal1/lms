import "server-only";

import { apiGet } from "@/lib/server/api";

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
export async function getPublicPricingTiers(audience: "individual" | "org"): Promise<PricingTier[]> {
  const { tiers } = await apiGet<{ tiers: PricingTier[] }>(`/api/public/pricing?audience=${audience}`);
  return tiers;
}

/** Every tier across both audiences, for the /platform/pricing admin page. */
export async function getAdminPricingTiers(): Promise<PricingTier[]> {
  const { tiers } = await apiGet<{ tiers: PricingTier[] }>("/api/admin/pricing");
  return tiers;
}
