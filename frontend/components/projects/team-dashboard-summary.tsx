import { GitCommitHorizontal, GitPullRequest, Users } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { PIPELINE_STATUS_VARIANT } from "@/components/projects/team-activity-feed";
import type { TeamDashboardSummary as TeamDashboardSummaryType } from "@/lib/projects/types";

interface TeamDashboardSummaryProps {
  dashboard: TeamDashboardSummaryType;
}

// Small stat-tile row for the assignment-wide dashboard's per-team numbers —
// GET /api/projects/assignments/{assignmentID}/dashboard. Deliberately just
// the rolled-up counts (commits, MRs, latest pipeline, free-riders); the
// unaggregated recent-commits/MRs list stays TeamActivityFeed's job, so this
// doesn't duplicate that sheet.
export function TeamDashboardSummary({ dashboard }: TeamDashboardSummaryProps) {
  return (
    <div className="flex flex-wrap items-center gap-x-4 gap-y-1.5 rounded-md bg-muted/50 px-3 py-2 text-xs">
      <span className="inline-flex items-center gap-1 text-muted-foreground">
        <GitCommitHorizontal aria-hidden className="h-3.5 w-3.5" />
        {dashboard.commit_count} commit{dashboard.commit_count === 1 ? "" : "s"}
      </span>
      <span className="inline-flex items-center gap-1 text-muted-foreground">
        <GitPullRequest aria-hidden className="h-3.5 w-3.5" />
        {dashboard.open_mr_count} open · {dashboard.merged_mr_count} merged
      </span>
      {dashboard.latest_pipeline_status && (
        <Badge className="h-5 px-1.5 text-[10px]" variant={PIPELINE_STATUS_VARIANT[dashboard.latest_pipeline_status] ?? "outline"}>
          {dashboard.latest_pipeline_status}
        </Badge>
      )}
      {dashboard.free_rider_count > 0 && (
        <span className="badge-muted inline-flex items-center gap-1 rounded-md border px-1.5 py-0.5 text-[10px]">
          <Users aria-hidden className="h-3 w-3" />
          {dashboard.free_rider_count} no commits yet
        </span>
      )}
    </div>
  );
}
