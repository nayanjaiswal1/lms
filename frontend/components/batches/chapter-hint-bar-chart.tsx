"use client";

import dynamic from "next/dynamic";
import { Skeleton } from "@/components/ui/skeleton";
import type { ChapterHintStat } from "@/lib/server/batches";

const ChapterHintBarChartInner = dynamic(() => import("@/components/batches/chapter-hint-bar-chart-inner"), {
  ssr: false,
  loading: () => <Skeleton className="h-40 w-full" />,
});

interface ChapterHintBarChartProps {
  stats: ChapterHintStat[];
}

export function ChapterHintBarChart({ stats }: ChapterHintBarChartProps) {
  if (stats.length === 0) {
    return (
      <div className="empty-state py-10">
        <p className="text-sm text-muted-foreground">No chapters assigned to this batch yet.</p>
      </div>
    );
  }
  return <ChapterHintBarChartInner stats={stats} />;
}
