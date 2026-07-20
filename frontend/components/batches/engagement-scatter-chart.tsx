"use client";

import dynamic from "next/dynamic";
import { Skeleton } from "@/components/ui/skeleton";
import type { EngagementPoint } from "@/lib/server/batches";

const EngagementScatterChartInner = dynamic(() => import("@/components/batches/engagement-scatter-chart-inner"), {
  ssr: false,
  loading: () => <Skeleton className="h-80 w-full" />,
});

const QUADRANTS = [
  { label: "Stars", className: "bg-success" },
  { label: "Naturally strong", className: "bg-ai" },
  { label: "Struggling", className: "bg-warning" },
  { label: "Intervention needed", className: "bg-destructive" },
];

interface EngagementScatterChartProps {
  points: EngagementPoint[];
}

export function EngagementScatterChart({ points }: EngagementScatterChartProps) {
  if (points.length === 0) {
    return (
      <div className="empty-state py-10">
        <p className="text-sm text-muted-foreground">No activity data yet.</p>
      </div>
    );
  }
  return (
    <div className="flex flex-col gap-3">
      <EngagementScatterChartInner points={points} />
      <div className="flex flex-wrap gap-x-5 gap-y-1.5 text-xs">
        {QUADRANTS.map((q) => (
          <div className="flex items-center gap-1.5" key={q.label}>
            <span aria-hidden className={`inline-block h-2.5 w-2.5 rounded-full ${q.className}`} />
            <span className="text-muted-foreground">{q.label}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
