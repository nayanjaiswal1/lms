import type { Metadata } from "next";
import { Check, Sparkles } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { IconMessage } from "@/components/shared/icon-message";
import { getFeatureConfig } from "@/lib/server/features";
import { FEATURE_META, PLAN_TIERS, type Feature } from "@/lib/features";

export const metadata: Metadata = {
  title: "Billing & Plans",
  description: "Your organization's plan and feature entitlements.",
};

interface BillingPageProps {
  searchParams: Promise<{ feature?: string }>;
}

export default async function BillingPage({ searchParams }: BillingPageProps) {
  const { feature } = await searchParams;
  const { entitlements } = await getFeatureConfig();
  const highlighted = feature && feature in FEATURE_META ? (feature as Feature) : undefined;

  return (
    <main className="page-container">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">Billing & Plans</h1>
          <p className="text-muted-foreground">Your organization&apos;s plan and feature entitlements.</p>
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
        {PLAN_TIERS.map((tier) => (
          <article className="card-base flex flex-col gap-4 p-6" key={tier.id}>
            <div className="flex items-start justify-between gap-2">
              <h3 className="text-lg font-semibold">{tier.name}</h3>
              {tier.id === "free" && <Badge>Current</Badge>}
            </div>
            <p className="text-2xl font-bold">{tier.price}</p>
            <p className="text-sm text-muted-foreground">{tier.tagline}</p>

            {tier.id === "free" && (
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

            <Button className="mt-auto w-full" disabled={tier.ctaDisabled} variant={tier.id === "free" ? "outline" : "default"}>
              {tier.cta}
            </Button>
          </article>
        ))}
      </section>
    </main>
  );
}
