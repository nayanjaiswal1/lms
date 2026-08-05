import Link from "next/link";
import { ArrowRight } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Reveal } from "@/components/landing/landing-motion";

interface Cta {
  label: string;
  href: string;
}

interface LandingCtaProps {
  heading: string;
  description: string;
  primaryCta: Cta;
  secondaryCta?: Cta;
}

export function LandingCta({ heading, description, primaryCta, secondaryCta }: LandingCtaProps) {
  return (
    <section aria-labelledby="cta-heading" className="py-16 sm:py-24">
      <Reveal className="page-container text-center">
        <h2 className="text-2xl font-bold sm:text-3xl" id="cta-heading">
          {heading}
        </h2>
        <p className="mx-auto mt-2 max-w-xl text-sm text-muted-foreground">{description}</p>
        <div className="mt-6 flex flex-wrap items-center justify-center gap-3">
          <Button asChild size="lg">
            <Link href={primaryCta.href}>
              {primaryCta.label}
              <ArrowRight aria-hidden className="h-4 w-4" />
            </Link>
          </Button>
          {secondaryCta && (
            <Button asChild size="lg" variant="outline">
              <Link href={secondaryCta.href}>{secondaryCta.label}</Link>
            </Button>
          )}
        </div>
      </Reveal>
    </section>
  );
}
