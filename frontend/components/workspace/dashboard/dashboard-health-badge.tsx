"use client";

import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { cn } from "@/lib/utils";
import type { HealthReport } from "@/lib/workspace/types";

const HEALTH_DOT_CLASS: Record<HealthReport["color"], string> = {
  green: "bg-success",
  yellow: "bg-warning",
  red: "bg-destructive",
};

const HEALTH_LABEL: Record<HealthReport["color"], string> = {
  green: "Healthy",
  yellow: "Needs attention",
  red: "At risk",
};

interface DashboardHealthBadgeProps {
  health: HealthReport;
}

/** Click reveals why (contract-phase4.md 04 §5: "header with health badge
 * (click → reasons)"). */
export function DashboardHealthBadge({ health }: DashboardHealthBadgeProps) {
  return (
    <Popover>
      <PopoverTrigger asChild>
        <button
          className="flex items-center gap-2 rounded-md border border-border px-3 py-1.5 text-sm font-medium transition-colors duration-fast hover:bg-muted"
          type="button"
        >
          <span aria-hidden className={cn("h-2.5 w-2.5 rounded-full", HEALTH_DOT_CLASS[health.color])} />
          {HEALTH_LABEL[health.color]}
        </button>
      </PopoverTrigger>
      <PopoverContent align="start" className="w-80">
        {health.reasons.length === 0 ? (
          <p className="text-sm text-muted-foreground">No health concerns right now.</p>
        ) : (
          <ul className="flex flex-col gap-1.5 text-sm">
            {health.reasons.map((reason) => (
              <li className="text-foreground" key={reason}>
                {reason}
              </li>
            ))}
          </ul>
        )}
      </PopoverContent>
    </Popover>
  );
}
