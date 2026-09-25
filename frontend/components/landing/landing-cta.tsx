
import { LandingCtaButtons } from "@/components/landing/landing-cta-buttons";
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
        <LandingCtaButtons className="mt-6 sm:justify-center" primaryCta={primaryCta} secondaryCta={secondaryCta} />
      </Reveal>
    </section>
  );
}
