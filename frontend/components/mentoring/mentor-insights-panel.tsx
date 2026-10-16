import { formatResponseTime } from "@/lib/mentoring/format";
import { cn } from "@/lib/utils";

interface MentorInsightsPanelProps {
  menteeCount: number;
  avgRating: number | null;
  ratingCount: number;
  avgResponseMinutes: number | null;
  percentileRank: number | null;
}

interface StatTileProps {
  label: string;
  value: string;
  hint?: string;
  highlighted?: boolean;
  wide?: boolean;
}

function StatTile({ label, value, hint, highlighted = false, wide = false }: StatTileProps) {
  return (
    <div className={cn("flex min-w-0 flex-col gap-0.5 rounded-lg bg-muted/50 p-4", wide && "col-span-2")}>
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className={cn("text-2xl font-semibold tabular-nums", highlighted ? "text-primary" : "text-foreground")}>{value}</dd>
      {hint && <dd className="text-xs text-muted-foreground">{hint}</dd>}
    </div>
  );
}

// The "Professional Insights" card — three live-computed stats plus, when the
// mentor has enough activity this month to rank, a percentile bar.
// percentileRank is 0 (top) to 1 (bottom) from PERCENT_RANK(); omitted
// entirely when null rather than showing a meaningless 0%. Page-specific
// (not the shared StatCard grid) since only this page uses this compact layout.
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
    <section aria-labelledby="mentor-insights-title" className="card-raised flex flex-col gap-4">
      <h2 className="subsection-title" id="mentor-insights-title">
        At a glance
      </h2>

      <dl className="grid grid-cols-2 gap-3">
        <StatTile label="Active mentees" value={String(menteeCount)} />
        <StatTile
          highlighted
          hint={ratingCount > 0 ? `${ratingCount} rating${ratingCount === 1 ? "" : "s"}` : undefined}
          label="Average rating"
          value={avgRating !== null ? avgRating.toFixed(1) : "—"}
        />
        <StatTile label="Typical response time" value={responseLabel ?? "No data yet"} wide />
      </dl>

      {topPercent !== null && (
        <div className="flex flex-col gap-2">
          <div className="progress-track">
            <div className="progress-fill" style={{ "--progress": `${100 - topPercent}%` } as React.CSSProperties} />
          </div>
          <p className="text-sm text-muted-foreground">
            Top <span className="font-semibold text-primary">{topPercent}%</span> of mentors this month
          </p>
        </div>
      )}
    </section>
  );
}
