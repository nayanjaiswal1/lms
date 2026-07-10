import Link from "next/link";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";
import type { UserSheetSummary } from "@/lib/server/sheets";

interface SheetTabsProps {
  sheets: UserSheetSummary[];
  activeSlug?: string;
}

export function SheetTabs({ sheets, activeSlug }: SheetTabsProps) {
  return (
    <div
      aria-label="Your sheets"
      className="flex gap-1 overflow-x-auto border-b border-border -mt-1 mb-4"
      role="tablist"
    >
      {sheets.map((sheet) => {
        const isActive = sheet.slug === activeSlug;
        return (
          <Link
            aria-selected={isActive}
            className={cn(
              "shrink-0 whitespace-nowrap px-3 py-2 text-sm font-medium border-b-2 transition-colors duration-fast",
              isActive
                ? "text-primary border-primary"
                : "text-muted-foreground border-transparent hover:text-foreground hover:border-border",
            )}
            href={`${ROUTES.SHEETS}?sheet=${encodeURIComponent(sheet.slug)}`}
            key={sheet.id}
            role="tab"
          >
            {sheet.name}
          </Link>
        );
      })}
    </div>
  );
}
