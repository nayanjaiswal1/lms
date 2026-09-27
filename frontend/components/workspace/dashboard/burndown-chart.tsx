"use client";

import dynamic from "next/dynamic";
import { TrendingDown } from "lucide-react";

import { Skeleton } from "@/components/ui/skeleton";
import type { DayPoint } from "@/lib/workspace/types";

const BurndownChartInner = dynamic(() => import("@/components/workspace/dashboard/burndown-chart-inner"), {
  ssr: false,
  loading: () => <Skeleton className="h-60 w-full" />,
});

export function BurndownChart({ burndown }: { burndown: DayPoint[] }) {
  if (burndown.length === 0) {
    return (
      <div className="empty-state py-8">
        <TrendingDown aria-hidden className="empty-state-icon" />
        <p className="text-sm text-muted-foreground">No burndown data for this range yet.</p>
      </div>
    );
  }
  return <BurndownChartInner burndown={burndown} />;
}
