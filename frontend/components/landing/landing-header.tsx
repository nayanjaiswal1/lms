import Link from "next/link";

import { Button } from "@/components/ui/button";
import { BrandMark } from "@/components/shared/brand-mark";
import { LandingAudienceTabs } from "@/components/landing/landing-audience-tabs";
import ROUTES from "@/lib/routes";

interface NavLink {
  label: string;
  href: string;
}

interface LandingHeaderProps {
  audience: "individual" | "org";
  navLinks: readonly NavLink[];
}

export function LandingHeader({ audience, navLinks }: LandingHeaderProps) {
  return (
    <header className="sticky top-0 z-raised border-b border-border bg-background/80 backdrop-blur">
      <div className="page-container flex h-14 items-center justify-between gap-2 sm:gap-4">
        <div className="flex min-w-0 items-center gap-6">
          <Link href={ROUTES.HOME}>
            {/* Glyph-only below sm: logo + name + both CTAs overflow a 360px row and
                scroll the page sideways. Name stays in the a11y tree via sr-only. */}
            <BrandMark nameClassName="sr-only sm:not-sr-only" />
          </Link>
          <LandingAudienceTabs audience={audience} className="hidden md:grid" />
        </div>

        <nav aria-label="Main" className="hidden items-center gap-6 lg:flex">
          {navLinks.map(({ label, href }) => (
            <a
              className="text-sm font-medium text-muted-foreground transition-colors duration-fast hover:text-foreground"
              href={href}
              key={href}
            >
              {label}
            </a>
          ))}
        </nav>

        <div className="flex shrink-0 items-center gap-1 sm:gap-2">
          <Button asChild variant="ghost">
            <Link href={ROUTES.LOGIN}>Log in</Link>
          </Button>
          <Button asChild>
            <Link href={ROUTES.REGISTER}>Get started</Link>
          </Button>
        </div>
      </div>

      <div className="border-t border-border py-2 md:hidden">
        <div className="page-container">
          <LandingAudienceTabs audience={audience} />
        </div>
      </div>
    </header>
  );
}
