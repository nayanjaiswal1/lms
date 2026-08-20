import type { Metadata } from "next";
import { Check, Lock, Sparkles } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { IconMessage } from "@/components/shared/icon-message";
import { getFeatureConfig } from "@/lib/server/features";
import { getMyUsage } from "@/lib/server/entitlements";
import { getPublicPricingTiers } from "@/lib/server/pricing";
import { FEATURE_META, type Feature, type LockedFeatureInfo } from "@/lib/features";

export const metadata: Metadata = {
  title: "Billing & Plans",
  description: "Your plan, entitlements, and usage.",
};

interface BillingPageProps {
  searchParams: Promise<{ feature?: string }>;
}

export default async function BillingPage({ searchParams }: BillingPageProps) {
  const { feature } = await searchParams;
  const [{ entitlements, lockedInfo }, myUsage, tiers] = await Promise.all([
    getFeatureConfig(),
    getMyUsage(),
    getPublicPricingTiers("individual"),
  ]);
  const highlighted = feature && feature in FEATURE_META ? (feature as Feature) : undefined;
  const lockedFeatures = Object.entries(lockedInfo) as [Feature, LockedFeatureInfo][];

  return (
    <main className="page-container">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">Billing & Plans</h1>
          <p className="text-muted-foreground">Your plan, entitlements, and usage.</p>
        </div>
      </header>

      {highlighted && (
        <IconMessage
          className="ai-surface mb-6 rounded-[--radius-md] px-4 py-3 text-ai"
          icon={Sparkles}
          tone="ai"
          variant="plain"
        >
          <span className="font-medium">{FEATURE_META[highlighted].label}</span> is included in your current plan — see below.
        </IconMessage>
      )}

      <section className="grid-responsive">
        {tiers.map((tier) => (
          <article className="card-base flex flex-col gap-4 p-6" key={tier.id}>
            <div className="flex items-start justify-between gap-2">
              <h3 className="text-lg font-semibold">{tier.name}</h3>
              {tier.id === myUsage.tier_id && <Badge>Current</Badge>}
            </div>
            <p className="text-2xl font-bold">{tier.price}</p>
            <p className="text-sm text-muted-foreground">{tier.tagline}</p>

            {tier.id === myUsage.tier_id && (
              <ul className="flex flex-col gap-1.5 text-sm">
                {entitlements.map((f) => (
                  <li className="flex items-center gap-2" key={f}>
                    <Check aria-hidden className="h-4 w-4 shrink-0 text-primary" />
                    <span className={f === highlighted ? "font-medium text-ai" : undefined}>
                      {FEATURE_META[f]?.label ?? f}
                    </span>
                  </li>
                ))}
              </ul>
            )}

            <Button className="mt-auto w-full" disabled={tier.cta_disabled} variant={tier.id === myUsage.tier_id ? "outline" : "default"}>
              {tier.cta_label}
            </Button>
          </article>
        ))}
      </section>

      {lockedFeatures.length > 0 && (
        <section className="mt-10">
          <h2 className="section-title mb-4">Locked on your plan</h2>
          <div className="grid-responsive">
            {lockedFeatures.map(([key, info]) => (
              <div className="card-base flex flex-col gap-2 p-5" key={key}>
                <div className="flex items-center gap-2">
                  <Lock aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
                  <p className="font-medium">{FEATURE_META[key]?.label ?? key}</p>
                </div>
                <p className="text-sm text-muted-foreground">{info.reason}</p>
                <Badge className="w-fit" variant="secondary">
                  {info.cta_label}
                </Badge>
              </div>
            ))}
          </div>
        </section>
      )}

      {myUsage.usage.length > 0 && (
        <section className="mt-10">
          <h2 className="section-title mb-4">Usage this month</h2>
          <div className="grid-responsive">
            {myUsage.usage.map((u) => {
              const pct = u.limit > 0 ? Math.min(100, Math.round((u.used / u.limit) * 100)) : 0;
              return (
                <div className="card-base flex flex-col gap-3 p-5" key={u.feature_key}>
                  <div className="flex items-center justify-between text-sm">
                    <span className="font-medium">
                      {u.feature_key === "lab_hours" ? "Lab hours" : u.feature_key}
                    </span>
                    <span className="text-muted-foreground">
                      {u.used} / {u.limit} hrs
                    </span>
                  </div>
                  <div className="progress-track h-2">
                    {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width requires inline style */}
                    <div aria-hidden className="progress-fill h-full" style={{ width: `${pct}%` }} />
                  </div>
                </div>
              );
            })}
          </div>
        </section>
      )}
    </main>
  );
}
