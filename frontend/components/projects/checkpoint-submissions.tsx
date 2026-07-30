import { SubmissionRow } from "@/components/projects/submission-row";
import type { ProjectCheckpoint, ProjectTeam, ProjectTeamCheckpoint } from "@/lib/projects/types";

interface CheckpointSubmissionsProps {
  checkpoint: ProjectCheckpoint;
  submissions: ProjectTeamCheckpoint[];
  teamsById: Record<string, ProjectTeam>;
  assignmentId: string;
  requiredApprovals: number;
}

// Per-checkpoint submission view (staff): every team's MR state, approval
// progress, CI status, and the Merge/Grade/Comment actions — one
// <SubmissionRow> per team, this component just supplies the team name join
// (submissions carry team_id only, not a name) and the empty state.
export function CheckpointSubmissions({
  checkpoint,
  submissions,
  teamsById,
  assignmentId,
  requiredApprovals,
}: CheckpointSubmissionsProps) {
  if (submissions.length === 0) {
    return <p className="text-xs text-muted-foreground">No team has submitted against this checkpoint yet.</p>;
  }

  return (
    <div className="flex flex-col gap-3">
      {submissions.map((submission) => (
        <SubmissionRow
          assignmentId={assignmentId}
          checkpoint={checkpoint}
          key={submission.id}
          requiredApprovals={requiredApprovals}
          submission={submission}
          teamName={teamsById[submission.team_id]?.name ?? "Unknown team"}
        />
      ))}
    </div>
  );
}
