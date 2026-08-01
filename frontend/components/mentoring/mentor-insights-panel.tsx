import { Clock, Star, Users } from "lucide-react";
import { StatCard } from "@/components/shared/stat-card";
import { formatResponseTime } from "@/lib/mentoring/format";

interface MentorInsightsPanelProps {
  menteeCount: number;
  avgRating: number | null;
  ratingCount: number;
  avgResponseMinutes: number | null;
  percentileRank: number | null;
}

// The "Professional Insights" sidebar block on the mentor profile page —
// three live-computed StatCards plus, when the mentor has enough activity
// this month to rank, a percentile bar. percentileRank is 0 (top) to 1
// (bottom) from PERCENT_RANK(); omitted entirely when null rather than
// showing a meaningless 0%.
export function MentorInsightsPanel({
  menteeCount,
  avgRating,
  ratingCount,
  avgResponseMinutes,
  percentileRank,
}: MentorInsightsPanelProps) {
  const responseLabel = formatResponseTime(avgResponseMinutes);
  const topPercent = percentileRank !== null ? Math.max(1, Math.round(percentileRank * 100)) : null;

  return (
    <section className="flex flex-col gap-3">
      <h2 className="subsection-title">Professional insights</h2>
      <StatCard icon={Users} label="Active mentees" unit="mentored right now" value={String(menteeCount)} />
      <StatCard
        highlighted
        icon={Star}
        label="Average rating"
        unit={`${ratingCount} rating${ratingCount === 1 ? "" : "s"}`}
        value={avgRating !== null ? avgRating.toFixed(1) : "—"}
      />
      <StatCard
        icon={Clock}
        label="Response time"
        muted={responseLabel === null}
        unit="time to first reply"
        value={responseLabel ?? "No data yet"}
      />
      {topPercent !== null && (
        <div className="card-base flex flex-col gap-2 p-5">
          <div className="progress-track">
            {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width needs inline style */}
            <div className="progress-fill" style={{ "--progress": `${100 - topPercent}%` } as React.CSSProperties} />
          </div>
          <p className="text-center text-xs italic text-muted-foreground">
            Top {topPercent}% of mentors this month
          </p>
        </div>
      )}
    </section>
  );
}
