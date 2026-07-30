import { GitCommitHorizontal } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import type { ContributionRow } from "@/lib/projects/types";

interface ContributionBreakdownProps {
  contributions: ContributionRow[];
}

// Framed constructively — "here's what the team has contributed" — not a
// public shaming leaderboard. A member with zero commits gets a subtle,
// neutral badge instead of anything alarming/punitive.
export function ContributionBreakdown({ contributions }: ContributionBreakdownProps) {
  if (contributions.length === 0) {
    return (
      <div className="empty-state py-10">
        <GitCommitHorizontal aria-hidden className="empty-state-icon" />
        <p className="text-sm text-muted-foreground">No contribution activity recorded yet.</p>
      </div>
    );
  }

  const totalCommits = contributions.reduce((sum, c) => sum + c.commit_count, 0);

  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-muted-foreground">
        {totalCommits} commit{totalCommits === 1 ? "" : "s"} across {contributions.length} member
        {contributions.length === 1 ? "" : "s"}.
      </p>
      <ul className="divide-y divide-border rounded-md border border-border">
        {contributions.map((c) => (
          <li className="flex flex-wrap items-center justify-between gap-3 px-3 py-2.5 text-sm" key={c.user_id}>
            <div className="min-w-0">
              <p className="truncate font-medium">{c.name}</p>
              <p className="text-xs text-muted-foreground">
                {c.last_commit_at ? `Last commit ${new Date(c.last_commit_at).toLocaleDateString()}` : "No commits yet"}
              </p>
            </div>
            <div className="flex shrink-0 items-center gap-3">
              <span className="text-xs">
                <span className="text-success">+{c.additions}</span> <span className="text-destructive">-{c.deletions}</span>
              </span>
              <span className="text-sm font-semibold tabular-nums">
                {c.commit_count} commit{c.commit_count === 1 ? "" : "s"}
              </span>
              {c.is_free_rider && (
                <Badge className="badge-muted h-5 px-1.5 text-[10px]" variant="outline">
                  No commits
                </Badge>
              )}
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
