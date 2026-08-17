import type { ActivityEntry, UserOverview } from "@/app/(app)/users/[id]/types";

interface Props {
  overview: UserOverview;
  roleCount: number;
}

function habitStreakDays(overview: UserOverview): number {
  const activePeriods = new Set(overview.habit_month.completions.filter((c) => c.count > 0).map((c) => c.period_start));
  return activePeriods.size;
}

function StatTile({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="card-base p-4">
      <p className="text-2xl font-semibold text-foreground">{value}</p>
      <p className="text-xs text-muted-foreground mt-1">{label}</p>
    </div>
  );
}

function ActivityRow({ entry }: { entry: ActivityEntry }) {
  return (
    <div className="flex items-start gap-3 py-3 border-b border-border last:border-0">
      <div className="min-w-0 flex-1">
        <p className="text-sm font-medium text-foreground truncate">{entry.title}</p>
        {entry.summary && <p className="text-sm text-muted-foreground mt-0.5 line-clamp-2">{entry.summary}</p>}
      </div>
      <span className="shrink-0 text-xs text-muted-foreground whitespace-nowrap">
        {new Date(entry.occurred_at).toLocaleDateString()}
      </span>
    </div>
  );
}

export function OverviewTab({ overview, roleCount }: Props) {
  const mistakesOpen = overview.mistakes.filter((m) => m.resolved_at === null).length;

  return (
    <div className="space-y-6">
      <div className="grid-stats">
        <StatTile label="Courses enrolled" value={overview.enrollments.length} />
        <StatTile label="Sheets tracked" value={overview.sheets.length} />
        <StatTile label="Open mistakes" value={mistakesOpen} />
        <StatTile label="Active habit days" value={habitStreakDays(overview)} />
        <StatTile label="Journal entries" value={overview.journal_entries.length} />
        <StatTile label="RBAC roles" value={roleCount} />
      </div>

      <div className="card-base p-6">
        <h3 className="subsection-title text-foreground mb-2">Recent activity</h3>
        {overview.recent_activity.length === 0 ? (
          <p className="text-sm text-muted-foreground">No recorded activity yet.</p>
        ) : (
          <div>
            {overview.recent_activity.map((entry) => (
              <ActivityRow entry={entry} key={entry.key} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
