"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import type { PricingTier } from "@/lib/server/pricing";
import ROUTES from "@/lib/routes";

export interface UpdatePricingTierInput {
  name: string;
  price: string;
  billing_note: string;
  tagline: string;
  features: string[];
  cta_label: string;
  cta_disabled: boolean;
  cta_href?: string;
  highlighted: boolean;
}

// Revalidates the admin list plus both public landing pages — apiGet already
// fetches with cache: "no-store" so the data itself is never stale, but the
// Next.js router cache still needs a nudge to re-render a page the visitor
// was already sitting on.
export async function updatePricingTierAction(
  id: string,
  input: UpdatePricingTierInput,
): Promise<ActionResult<PricingTier>> {
  const result = await apiAction<PricingTier>("PATCH", `/api/admin/pricing/${id}`, input);
  if (result.ok) {
    revalidatePath(ROUTES.PLATFORM_PRICING);
    revalidatePath(ROUTES.HOME);
    revalidatePath(ROUTES.ORG_LANDING);
  }
  return result;
}
