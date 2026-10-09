import { getWorkspaceDashboard } from "@/lib/workspace/phase4-server";
import { getWorkspaceCheckpoints, getWorkspaceContributions } from "@/lib/workspace/gitlab-server";

interface ShowcaseStatsCardProps {
  workspaceId: string;
}

/** Showcase numbers for a workspace with a GitLab team. Any fetch failure
 * omits the card rather than breaking the Home page. */
export async function ShowcaseStatsCard({ workspaceId }: ShowcaseStatsCardProps) {
  let stats: { label: string; value: string }[];
  try {
    const [checkpoints, contributions, dashboard] = await Promise.all([
      getWorkspaceCheckpoints(workspaceId),
      getWorkspaceContributions(workspaceId),
      getWorkspaceDashboard(workspaceId),
    ]);
    const scores = checkpoints.checkpoints.flatMap((c) => (c.score === null ? [] : [c.score]));
    const average = scores.length > 0 ? (scores.reduce((a, b) => a + b, 0) / scores.length).toFixed(1) : "—";
    stats = [
      { label: "Graded checkpoints", value: String(scores.length) },
      { label: "Average score", value: average },
      { label: "Commits", value: String(contributions.contributions.reduce((n, c) => n + c.commit_count, 0)) },
      { label: "Tasks done", value: String(dashboard.people.reduce((n, p) => n + p.completed_owned, 0)) },
    ];
  } catch {
    return null;
  }

  return (
    <section aria-label="Showcase stats" className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {stats.map((s) => (
        <div className="card-base" key={s.label}>
          <p className="text-xs text-muted-foreground">{s.label}</p>
          <p className="mt-1 text-lg font-semibold">{s.value}</p>
        </div>
      ))}
    </section>
  );
}
