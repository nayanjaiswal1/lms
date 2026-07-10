import Link from "next/link";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";
import type { GroupBy } from "@/components/sheets/sheet-table";

interface GroupToggleProps {
  activeSlug: string;
  groupBy: GroupBy;
}

const OPTIONS: { value: GroupBy; label: string }[] = [
  { value: "none", label: "None" },
  { value: "topic", label: "Topic" },
  { value: "difficulty", label: "Difficulty" },
];

export function GroupToggle({ activeSlug, groupBy }: GroupToggleProps) {
  return (
    <div aria-label="Group by" className="inline-flex items-center gap-1 rounded-md bg-muted p-1" role="group">
      <span className="px-2 text-xs font-medium text-muted-foreground">Group:</span>
      {OPTIONS.map((option) => {
        const isActive = option.value === groupBy;
        const href =
          option.value === "none"
            ? `${ROUTES.SHEETS}?sheet=${encodeURIComponent(activeSlug)}`
            : `${ROUTES.SHEETS}?sheet=${encodeURIComponent(activeSlug)}&group=${option.value}`;
        return (
          <Link
            aria-pressed={isActive}
            className={cn(
              "rounded-sm px-2.5 py-1 text-xs font-medium transition-colors duration-fast",
              isActive
                ? "bg-background text-foreground shadow-card"
                : "text-muted-foreground hover:text-foreground",
            )}
            href={href}
            key={option.value}
          >
            {option.label}
          </Link>
        );
      })}
    </div>
  );
}
