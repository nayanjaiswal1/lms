"use client";

import dynamic from "next/dynamic";
import { Skeleton } from "@/components/ui/skeleton";
import type { FunnelCounts } from "@/lib/server/course-analytics";

const FunnelChartInner = dynamic(() => import("@/components/courses/analytics/funnel-chart-inner"), {
  ssr: false,
  loading: () => <Skeleton className="h-52 w-full" />,
});

export function FunnelChart({ funnel }: { funnel: FunnelCounts }) {
  if (funnel.enrolled === 0) {
    return (
      <div className="empty-state py-10">
        <p className="text-sm text-muted-foreground">No students have enrolled yet.</p>
      </div>
    );
  }
  return <FunnelChartInner funnel={funnel} />;
}
