import Link from "next/link";
import ROUTES from "@/lib/routes";
import { cn } from "@/lib/utils";

const TABS = [
  { key: "all", label: "All", href: ROUTES.PLATFORM_HIGHLIGHTS },
  { key: "by-source", label: "By Source Type", href: ROUTES.PLATFORM_HIGHLIGHTS_BY_SOURCE },
  { key: "by-model", label: "By Model", href: ROUTES.PLATFORM_HIGHLIGHTS_BY_MODEL },
] as const;

interface Props {
  active: (typeof TABS)[number]["key"];
}

// Three lenses on the same highlight-analytics data, consolidated under one
// sidebar entry (Highlights) with in-page tabs instead of three separate nav rows.
export function HighlightsTabs({ active }: Props) {
  return (
    <div aria-label="Highlights view" className="flex gap-1 border-b border-border mb-6" role="tablist">
      {TABS.map((tab) => (
        <Link
          aria-selected={tab.key === active}
          className={cn(
            "px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors",
            tab.key === active
              ? "border-primary text-foreground"
              : "border-transparent text-muted-foreground hover:text-foreground",
          )}
          href={tab.href}
          key={tab.key}
          role="tab"
        >
          {tab.label}
        </Link>
      ))}
    </div>
  );
}
