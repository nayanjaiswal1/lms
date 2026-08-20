import type { Metadata } from "next";

import { getAdminPricingTiers } from "@/lib/server/pricing";
import { getAdminPlanLimits, type PlanLimit } from "@/lib/server/entitlements";
import { PricingTierCard } from "./pricing-tier-card";

export const metadata: Metadata = { title: "Pricing" };

export default async function PlatformPricingPage() {
  const tiers = await getAdminPricingTiers();
  const limitsByTier = Object.fromEntries(
    await Promise.all(tiers.map(async (tier) => [tier.id, await getAdminPlanLimits(tier.id)] as [string, PlanLimit[]])),
  );
  const individual = tiers.filter((tier) => tier.audience === "individual");
  const org = tiers.filter((tier) => tier.audience === "org");

  return (
    <div className="page-container">
      <header className="page-header">
        <div>
          <h1 className="page-title">Pricing</h1>
          <p className="mt-1 text-muted-foreground">
            Edit the tiers shown on the / and /org landing pages. Changes go live immediately — no redeploy.
          </p>
        </div>
      </header>

      <section className="mt-6">
        <h2 className="section-title">Individual</h2>
        <div className="mt-4 grid-responsive">
          {individual.map((tier) => (
            <PricingTierCard key={tier.id} limits={limitsByTier[tier.id]} tier={tier} />
          ))}
        </div>
      </section>

      <section className="mt-10">
        <h2 className="section-title">Organization</h2>
        <div className="mt-4 grid-responsive">
          {org.map((tier) => (
            <PricingTierCard key={tier.id} limits={limitsByTier[tier.id]} tier={tier} />
          ))}
        </div>
      </section>
    </div>
  );
}
