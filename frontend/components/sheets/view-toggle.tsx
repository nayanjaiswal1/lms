import Link from "next/link";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

export type SheetView = "list" | "table";

interface ViewToggleProps {
  activeSlug: string;
  view: SheetView;
  /** Other active query params to carry over when switching view. */
  extraParams?: Record<string, string | undefined>;
}

const OPTIONS: { value: SheetView; label: string }[] = [
  { value: "list", label: "List" },
  { value: "table", label: "Table" },
];

export function ViewToggle({ activeSlug, view, extraParams }: ViewToggleProps) {
  return (
    <div aria-label="View" className="inline-flex items-center gap-1 rounded-md bg-muted p-1" role="group">
      <span className="px-2 text-xs font-medium text-muted-foreground">View:</span>
      {OPTIONS.map((option) => {
        const isActive = option.value === view;
        const qs = new URLSearchParams();
        for (const [key, value] of Object.entries(extraParams ?? {})) {
          if (value) qs.set(key, value);
        }
        if (option.value !== "list") qs.set("view", option.value);
        const query = qs.toString();
        return (
          <Link
            aria-pressed={isActive}
            className={cn(
              "touch-target rounded-sm px-3 text-xs font-medium transition-colors duration-fast",
              isActive ? "bg-background text-foreground shadow-card" : "text-muted-foreground hover:text-foreground",
            )}
            href={`${ROUTES.sheet(activeSlug)}${query ? `?${query}` : ""}`}
            key={option.value}
          >
            {option.label}
          </Link>
        );
      })}
    </div>
  );
}
