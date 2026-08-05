import Link from "next/link";
import type { ReactNode } from "react";
import { Check } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Reveal } from "@/components/landing/landing-motion";
import { cn } from "@/lib/utils";
import type { PricingTier } from "@/lib/server/pricing";

interface LandingPricingProps {
  title: string;
  subtitle: string;
  tiers: PricingTier[];
  note?: ReactNode;
}

export function LandingPricing({ title, subtitle, tiers, note }: LandingPricingProps) {
  return (
    <section
      aria-labelledby="pricing-heading"
      className="scroll-mt-16 border-b border-border py-16 sm:py-24"
      id="pricing"
    >
      <div className="page-container">
        <Reveal>
          <h2 className="text-center text-2xl font-bold sm:text-3xl" id="pricing-heading">
            {title}
          </h2>
          <p className="mx-auto mt-2 max-w-xl text-center text-sm text-muted-foreground">
            {subtitle}
          </p>
        </Reveal>

        <div className="mt-10 grid-responsive">
          {tiers.map((tier, index) => (
            <Reveal delay={index * 0.08} key={tier.id}>
              <article
                className={cn(
                  "card-base flex h-full flex-col gap-4 p-6",
                  tier.highlighted && "border-primary shadow-raised",
                )}
              >
                <div className="flex items-start justify-between gap-2">
                  <h3 className="text-lg font-semibold">{tier.name}</h3>
                  {tier.highlighted && <Badge>Most popular</Badge>}
                </div>
                <div className="flex items-baseline gap-1.5">
                  <span className="text-2xl font-bold">{tier.price}</span>
                  <span className="text-sm text-muted-foreground">{tier.billing_note}</span>
                </div>
                <p className="text-sm text-muted-foreground">{tier.tagline}</p>

                <ul className="flex flex-1 flex-col gap-2.5 text-sm">
                  {tier.features.map((feature) => (
                    <li className="flex items-start gap-2" key={feature}>
                      <Check aria-hidden className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
                      <span className="text-foreground">{feature}</span>
                    </li>
                  ))}
                </ul>

                <Button
                  asChild={!tier.cta_disabled && !!tier.cta_href}
                  className="mt-auto w-full"
                  disabled={tier.cta_disabled}
                  variant={tier.cta_disabled ? "outline" : "default"}
                >
                  {!tier.cta_disabled && tier.cta_href ? (
                    <Link href={tier.cta_href}>{tier.cta_label}</Link>
                  ) : (
                    tier.cta_label
                  )}
                </Button>
              </article>
            </Reveal>
          ))}
        </div>

        {note && (
          <Reveal className="mt-8 text-center text-sm text-muted-foreground" delay={0.1}>
            {note}
          </Reveal>
        )}
      </div>
    </section>
  );
}
