import Link from "next/link";

import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

const AUDIENCE_TABS = [
  { id: "individual", label: "For individuals", href: ROUTES.HOME },
  { id: "org", label: "For organizations", href: ROUTES.ORG_LANDING },
] as const;

interface LandingAudienceTabsProps {
  audience: "individual" | "org";
  className?: string;
}

/**
 * Individual/org segmented control. One markup for the desktop header slot and the
 * phone row under the header, so both look the same. Tabs are equal-width and
 * min-h-11 on phones (44px tap target); compact from md up.
 */
export function LandingAudienceTabs({ audience, className }: LandingAudienceTabsProps) {
  return (
    <nav aria-label="Audience" className={cn("grid grid-cols-2 gap-1 rounded-md border border-border bg-muted/40 p-1", className)}>
      {AUDIENCE_TABS.map((tab) => {
        const active = audience === tab.id;
        return (
          <Link
            aria-current={active ? "page" : undefined}
            className={cn(
              "flex min-h-11 items-center justify-center whitespace-nowrap rounded-sm px-3 text-sm font-medium transition-colors duration-fast md:min-h-0 md:py-1.5",
              active ? "bg-background text-foreground shadow-card" : "text-muted-foreground hover:text-foreground",
            )}
            href={tab.href}
            key={tab.id}
          >
            {tab.label}
          </Link>
        );
      })}
    </nav>
  );
}
