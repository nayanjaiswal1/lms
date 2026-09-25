import Link from "next/link";
import { ArrowRight } from "lucide-react";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

interface Cta {
  label: string;
  href: string;
}

interface LandingCtaButtonsProps {
  primaryCta: Cta;
  secondaryCta?: Cta;
  className?: string;
}

/**
 * Primary + optional secondary CTA pair shared by the hero and the closing CTA.
 * Phones: stacked, full-width, equal buttons. `flex-wrap` used to wrap them into
 * two rows of different widths, which read as uneven. sm+: side by side, auto width.
 */
export function LandingCtaButtons({ primaryCta, secondaryCta, className }: LandingCtaButtonsProps) {
  return (
    <div className={cn("stack-sm items-stretch sm:items-center", className)}>
      <Button asChild className="w-full sm:w-auto" size="lg">
        <Link href={primaryCta.href}>
          {primaryCta.label}
          <ArrowRight aria-hidden className="h-4 w-4" />
        </Link>
      </Button>
      {secondaryCta && (
        <Button asChild className="w-full sm:w-auto" size="lg" variant="outline">
          <Link href={secondaryCta.href}>{secondaryCta.label}</Link>
        </Button>
      )}
    </div>
  );
}
