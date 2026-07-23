import Link from "next/link";
import { Check, RotateCcw, Star } from "lucide-react";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

export type StatusFilter = "done" | "revisit" | "starred";

interface StatusFilterToggleProps {
  activeSlug: string;
  activeFilters: Set<StatusFilter>;
  /** Other active query params (e.g. `group=topic`) to carry over when toggling. */
  extraParams?: Record<string, string | undefined>;
}

const OPTIONS: { value: StatusFilter; label: string; icon: typeof Check }[] = [
  { value: "done", label: "Done", icon: Check },
  { value: "revisit", label: "Revisit", icon: RotateCcw },
  { value: "starred", label: "Starred", icon: Star },
];

export function StatusFilterToggle({ activeSlug, activeFilters, extraParams }: StatusFilterToggleProps) {
  return (
    <div aria-label="Filter by status" className="inline-flex items-center gap-1 rounded-md bg-muted p-1" role="group">
      {OPTIONS.map((option) => {
        const isActive = activeFilters.has(option.value);
        const nextFilters = new Set(activeFilters);
        if (isActive) nextFilters.delete(option.value);
        else nextFilters.add(option.value);

        const qs = new URLSearchParams();
        for (const [key, value] of Object.entries(extraParams ?? {})) {
          if (value) qs.set(key, value);
        }
        if (nextFilters.size > 0) qs.set("filter", [...nextFilters].join(","));
        const query = qs.toString();
        const href = `${ROUTES.sheet(activeSlug)}${query ? `?${query}` : ""}`;
        const Icon = option.icon;

        return (
          <Link
            aria-pressed={isActive}
            className={cn(
              "touch-target inline-flex items-center gap-1.5 rounded-sm px-3 text-xs font-medium transition-colors duration-fast",
              isActive
                ? "bg-background text-foreground shadow-card"
                : "text-muted-foreground hover:text-foreground",
            )}
            href={href}
            key={option.value}
          >
            <Icon aria-hidden className="h-3.5 w-3.5" />
            {option.label}
          </Link>
        );
      })}
    </div>
  );
}
