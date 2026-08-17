import { Trophy } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { UserLink } from "@/components/shared/user-link";
import type { LeaderboardRow } from "@/lib/projects/types";

interface AssignmentLeaderboardProps {
  leaderboard: LeaderboardRow[];
}

// Ranked commit-count table across every team under an assignment —
// GET /api/projects/assignments/{assignmentID}/leaderboard. LeaderboardRow
// carries no is_free_rider field of its own (unlike ContributionRow), so the
// same "zero commits" signal the backend uses for IsFreeRider is derived
// here from commit_count === 0, shown as a subtle badge — not the alarming/
// punitive red a "0 commits" flag could otherwise read as.
export function AssignmentLeaderboard({ leaderboard }: AssignmentLeaderboardProps) {
  if (leaderboard.length === 0) {
    return (
      <div className="empty-state py-10">
        <Trophy aria-hidden className="empty-state-icon" />
        <p className="text-sm text-muted-foreground">No students assigned to any team yet.</p>
      </div>
    );
  }

  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-xs text-muted-foreground">
            <th className="py-2 pr-2 font-medium">#</th>
            <th className="py-2 pr-2 font-medium">Student</th>
            <th className="py-2 pr-2 font-medium">Team</th>
            <th className="py-2 pr-2 text-right font-medium">Commits</th>
            <th className="py-2 pr-2 text-right font-medium">+/-</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {leaderboard.map((row) => (
            <tr key={row.user_id}>
              <td className="py-2 pr-2 tabular-nums text-muted-foreground">{row.rank}</td>
              <td className="py-2 pr-2">
                <div className="flex items-center gap-2">
                  <UserLink className="font-medium hover:underline" userId={row.user_id}>
                    {row.name}
                  </UserLink>
                  {row.commit_count === 0 && (
                    <Badge className="badge-muted h-5 px-1.5 text-[10px]" variant="outline">
                      No commits
                    </Badge>
                  )}
                </div>
                <p className="text-xs text-muted-foreground">{row.email}</p>
              </td>
              <td className="py-2 pr-2 text-muted-foreground">{row.team_name}</td>
              <td className="py-2 pr-2 text-right tabular-nums font-medium">{row.commit_count}</td>
              <td className="py-2 pr-2 text-right tabular-nums text-xs">
                <span className="text-success">+{row.additions}</span>{" "}
                <span className="text-destructive">-{row.deletions}</span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
