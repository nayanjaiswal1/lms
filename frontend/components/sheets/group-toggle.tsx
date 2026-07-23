import Link from "next/link";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";
import type { GroupBy } from "@/components/sheets/sheet-table";

interface GroupToggleProps {
  activeSlug: string;
  groupBy: GroupBy;
  /** Other active query params (e.g. `done=1`) to carry over when switching groups. */
  extraParams?: Record<string, string | undefined>;
}

const OPTIONS: { value: GroupBy; label: string }[] = [
  { value: "none", label: "None" },
  { value: "topic", label: "Topic" },
  { value: "difficulty", label: "Difficulty" },
];

export function GroupToggle({ activeSlug, groupBy, extraParams }: GroupToggleProps) {
  return (
    <div aria-label="Group by" className="inline-flex items-center gap-1 rounded-md bg-muted p-1" role="group">
      <span className="px-2 text-xs font-medium text-muted-foreground">Group:</span>
      {OPTIONS.map((option) => {
        const isActive = option.value === groupBy;
        const qs = new URLSearchParams();
        for (const [key, value] of Object.entries(extraParams ?? {})) {
          if (value) qs.set(key, value);
        }
        if (option.value !== "none") qs.set("group", option.value);
        const query = qs.toString();
        const href = `${ROUTES.sheet(activeSlug)}${query ? `?${query}` : ""}`;
        return (
          <Link
            aria-pressed={isActive}
            className={cn(
              "touch-target rounded-sm px-3 text-xs font-medium transition-colors duration-fast",
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
