import Link from "next/link";

import { Button } from "@/components/ui/button";
import { BrandMark } from "@/components/shared/brand-mark";
import { LandingMotionConfig } from "@/components/landing/landing-motion";
import { LandingHero } from "@/components/landing/landing-hero";
import { LandingStats } from "@/components/landing/landing-stats";
import { LandingAudience } from "@/components/landing/landing-audience";
import { LandingFeatures } from "@/components/landing/landing-features";
import { LandingFaq } from "@/components/landing/landing-faq";
import { LandingCta } from "@/components/landing/landing-cta";
import { LandingFooter } from "@/components/landing/landing-footer";
import ROUTES from "@/lib/routes";

const NAV_LINKS = [
  { label: "Features", href: "#features" },
  { label: "Individuals", href: "#individuals" },
  { label: "Teams", href: "#teams" },
  { label: "FAQ", href: "#faq" },
] as const;

interface LandingPageProps {
  total: number;
}

export function LandingPage({ total }: LandingPageProps) {
  return (
    <div className="min-h-dvh bg-background text-foreground">
      <header className="sticky top-0 z-raised border-b border-border bg-background/80 backdrop-blur">
        <nav
          aria-label="Main"
          className="page-container flex h-14 items-center justify-between gap-4"
        >
          <Link href={ROUTES.HOME}>
            <BrandMark />
          </Link>
          <div className="hidden items-center gap-6 md:flex">
            {NAV_LINKS.map(({ label, href }) => (
              <a
                className="text-sm font-medium text-muted-foreground transition-colors duration-fast hover:text-foreground"
                href={href}
                key={href}
              >
                {label}
              </a>
            ))}
          </div>
          <div className="flex items-center gap-2">
            <Button asChild variant="ghost">
              <Link href={ROUTES.LOGIN}>Log in</Link>
            </Button>
            <Button asChild>
              <Link href={ROUTES.REGISTER}>Get started</Link>
            </Button>
          </div>
        </nav>
      </header>

      <LandingMotionConfig>
        <main>
          <LandingHero courseTotal={total} />
          <LandingStats courseTotal={total} />
          <LandingAudience />
          <LandingFeatures />
          <LandingFaq />
          <LandingCta />
        </main>
      </LandingMotionConfig>

      <LandingFooter />
    </div>
  );
}
