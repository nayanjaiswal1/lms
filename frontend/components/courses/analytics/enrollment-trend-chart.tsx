"use client";

import dynamic from "next/dynamic";
import { Skeleton } from "@/components/ui/skeleton";
import type { EnrollmentPoint } from "@/lib/server/course-analytics";

const EnrollmentTrendChartInner = dynamic(() => import("@/components/courses/analytics/enrollment-trend-chart-inner"), {
  ssr: false,
  loading: () => <Skeleton className="h-52 w-full" />,
});

export function EnrollmentTrendChart({ points }: { points: EnrollmentPoint[] }) {
  if (points.every((p) => p.enrollments === 0)) {
    return (
      <div className="empty-state py-10">
        <p className="text-sm text-muted-foreground">No enrollments in this period.</p>
      </div>
    );
  }
  return <EnrollmentTrendChartInner points={points} />;
}
