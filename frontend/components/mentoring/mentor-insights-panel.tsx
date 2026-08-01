import { TrendingUp } from "lucide-react";
import { formatResponseTime } from "@/lib/mentoring/format";

interface MentorInsightsPanelProps {
  menteeCount: number;
  avgRating: number | null;
  ratingCount: number;
  avgResponseMinutes: number | null;
  percentileRank: number | null;
}

function StatRow({ label, value, highlighted = false }: { label: string; value: string; highlighted?: boolean }) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className={`text-2xl font-semibold ${highlighted ? "text-primary" : "text-foreground"}`}>{value}</span>
    </div>
  );
}

// The "Professional Insights" sidebar card — three live-computed stats plus,
// when the mentor has enough activity this month to rank, a percentile bar.
// percentileRank is 0 (top) to 1 (bottom) from PERCENT_RANK(); omitted
// entirely when null rather than showing a meaningless 0%. Page-specific
// (not the shared StatCard grid) since only this page uses this compact
// single-card layout.
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
    <section className="rounded-xl border border-border bg-card p-6 shadow-raised">
      <div className="mb-6 flex items-center justify-between">
        <h2 className="text-sm font-semibold uppercase tracking-wider text-foreground">Professional insights</h2>
        <TrendingUp aria-hidden className="h-5 w-5 text-muted-foreground" />
      </div>

      <div className="flex flex-col gap-5">
        <StatRow label="Active mentees" value={String(menteeCount)} />
        <StatRow highlighted label="Average rating" value={avgRating !== null ? avgRating.toFixed(1) : "—"} />
        {ratingCount > 0 && (
          <p className="-mt-3 text-right text-xs text-muted-foreground">
            {ratingCount} rating{ratingCount === 1 ? "" : "s"}
          </p>
        )}
        <StatRow label="Response time" value={responseLabel ?? "No data yet"} />

        {topPercent !== null && (
          <div className="flex flex-col gap-2">
            <div className="progress-track">
              <div className="progress-fill" style={{ "--progress": `${100 - topPercent}%` } as React.CSSProperties} />
            </div>
            <p className="text-center text-xs italic text-muted-foreground">
              Top {topPercent}% of mentors this month
            </p>
          </div>
        )}
      </div>
    </section>
  );
}
