"use client";

import dynamic from "next/dynamic";
import { Skeleton } from "@/components/ui/skeleton";
import type { CategorySummary } from "@/lib/server/mistakes";

const MistakeTrendChartInner = dynamic(() => import("@/components/mistakes/mistake-trend-chart-inner"), {
  ssr: false,
  loading: () => <Skeleton className="h-40 w-full" />,
});

interface MistakeTrendChartProps {
  summary: CategorySummary[];
}

export function MistakeTrendChart({ summary }: MistakeTrendChartProps) {
  if (summary.length === 0) {
    return (
      <div className="empty-state py-10">
        <p className="text-sm text-muted-foreground">No mistakes logged yet — your growth chart will appear here.</p>
      </div>
    );
  }
  return <MistakeTrendChartInner summary={summary} />;
}
