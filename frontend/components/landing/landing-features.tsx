import type { LucideIcon } from "lucide-react";

import { Reveal } from "@/components/landing/landing-motion";

export interface FeatureShowcaseItem {
  icon: LucideIcon;
  label: string;
  description: string;
}

interface LandingFeaturesProps {
  title: string;
  subtitle: string;
  items: FeatureShowcaseItem[];
}

export function LandingFeatures({ title, subtitle, items }: LandingFeaturesProps) {
  return (
    <section
      aria-labelledby="features-heading"
      className="scroll-mt-16 border-b border-border py-16 sm:py-24"
      id="features"
    >
      <div className="page-container">
        <Reveal>
          <h2 className="text-center text-2xl font-bold sm:text-3xl" id="features-heading">
            {title}
          </h2>
          <p className="mx-auto mt-2 max-w-xl text-center text-sm text-muted-foreground">
            {subtitle}
          </p>
        </Reveal>

        <ul className="card-grid mt-10">
          {items.map(({ icon: Icon, label, description }, index) => (
            <Reveal delay={(index % 3) * 0.08} key={label}>
              <li className="card-interactive h-full">
                <Icon aria-hidden className="h-6 w-6 text-primary" />
                <h3 className="mt-3 text-base font-semibold">{label}</h3>
                <p className="mt-1 text-sm text-muted-foreground">{description}</p>
              </li>
            </Reveal>
          ))}
        </ul>
      </div>
    </section>
  );
}
