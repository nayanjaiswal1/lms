import Link from "next/link";

import { Button } from "@/components/ui/button";
import { BrandMark } from "@/components/shared/brand-mark";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

interface NavLink {
  label: string;
  href: string;
}

interface LandingHeaderProps {
  audience: "individual" | "org";
  navLinks: readonly NavLink[];
}

const AUDIENCE_TABS = [
  { id: "individual", label: "For individuals", href: ROUTES.HOME },
  { id: "org", label: "For organizations", href: ROUTES.ORG_LANDING },
] as const;

export function LandingHeader({ audience, navLinks }: LandingHeaderProps) {
  return (
    <header className="sticky top-0 z-raised border-b border-border bg-background/80 backdrop-blur">
      <div className="page-container flex h-14 items-center justify-between gap-4">
        <div className="flex items-center gap-6">
          <Link href={ROUTES.HOME}>
            <BrandMark />
          </Link>
          <div className="hidden items-center gap-1 rounded-md border border-border bg-muted/40 p-1 md:flex">
            {AUDIENCE_TABS.map((tab) => (
              <Link
                className={cn(
                  "rounded-[--radius-sm] px-3 py-1.5 text-sm font-medium transition-colors duration-fast",
                  audience === tab.id
                    ? "bg-background text-foreground shadow-card"
                    : "text-muted-foreground hover:text-foreground",
                )}
                href={tab.href}
                key={tab.id}
              >
                {tab.label}
              </Link>
            ))}
          </div>
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

        <div className="flex items-center gap-2">
          <Button asChild variant="ghost">
            <Link href={ROUTES.LOGIN}>Log in</Link>
          </Button>
          <Button asChild>
            <Link href={ROUTES.REGISTER}>Get started</Link>
          </Button>
        </div>
      </div>

      <div className="flex items-center gap-1 border-t border-border p-2 md:hidden">
        {AUDIENCE_TABS.map((tab) => (
          <Link
            className={cn(
              "flex-1 rounded-[--radius-sm] py-1.5 text-center text-sm font-medium transition-colors duration-fast",
              audience === tab.id ? "bg-muted text-foreground" : "text-muted-foreground",
            )}
            href={tab.href}
            key={tab.id}
          >
            {tab.label}
          </Link>
        ))}
      </div>
    </header>
  );
}
