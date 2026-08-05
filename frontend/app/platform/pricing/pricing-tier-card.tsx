import { Badge } from "@/components/ui/badge";
import type { PricingTier } from "@/lib/server/pricing";
import { EditPricingTierDialog } from "./edit-pricing-tier-dialog";

interface PricingTierCardProps {
  tier: PricingTier;
}

export function PricingTierCard({ tier }: PricingTierCardProps) {
  return (
    <article className="card-base flex flex-col gap-3 p-6">
      <div className="flex items-start justify-between gap-2">
        <div>
          <h3 className="text-lg font-semibold">{tier.name}</h3>
          <p className="text-sm text-muted-foreground">{tier.tagline}</p>
        </div>
        {tier.highlighted && <Badge>Most popular</Badge>}
      </div>

      <div className="flex items-baseline gap-1.5">
        <span className="text-xl font-bold">{tier.price}</span>
        <span className="text-sm text-muted-foreground">{tier.billing_note}</span>
      </div>

      <ul className="flex flex-col gap-1 text-sm text-muted-foreground">
        {tier.features.map((feature) => (
          <li className="min-w-0 truncate" key={feature}>
            · {feature}
          </li>
        ))}
      </ul>

      <div className="mt-2 flex items-center justify-between gap-2 border-t border-border pt-3">
        <Badge variant={tier.cta_disabled ? "outline" : "default"}>
          {tier.cta_disabled ? "CTA disabled" : `Links to ${tier.cta_href}`}
        </Badge>
        <EditPricingTierDialog tier={tier} />
      </div>
    </article>
  );
}
