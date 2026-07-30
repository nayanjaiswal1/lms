import { CheckpointDialog } from "@/components/projects/checkpoint-dialog";
import { DeleteCheckpointButton } from "@/components/projects/delete-checkpoint-button";
import { CheckpointSubmissions } from "@/components/projects/checkpoint-submissions";
import type { ProjectCheckpoint, ProjectTeam, ProjectTeamCheckpoint } from "@/lib/projects/types";

interface CheckpointListProps {
  assignmentId: string;
  requiredApprovals: number;
  checkpoints: ProjectCheckpoint[];
  submissionsByCheckpoint: Record<string, ProjectTeamCheckpoint[]>;
  teamsById: Record<string, ProjectTeam>;
}

// Staff checkpoint CRUD + per-checkpoint submissions, embedded directly under
// each checkpoint card rather than behind a separate expand/collapse toggle —
// an assignment has few enough checkpoints that always showing submissions
// needs no extra client-side "which one is open" state at all.
export function CheckpointList({
  assignmentId,
  requiredApprovals,
  checkpoints,
  submissionsByCheckpoint,
  teamsById,
}: CheckpointListProps) {
  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-4">
        <h3 className="text-sm font-semibold">Checkpoints</h3>
        <CheckpointDialog assignmentId={assignmentId} nextPosition={checkpoints.length + 1} />
      </div>

      {checkpoints.length === 0 ? (
        <p className="py-4 text-center text-sm text-muted-foreground">
          No checkpoints yet. Add one to start collecting team submissions.
        </p>
      ) : (
        checkpoints.map((cp) => (
          <article className="card-base flex flex-col gap-3 p-6" key={cp.id}>
            <div className="flex items-start justify-between gap-2">
              <div className="flex flex-col gap-0.5">
                <span className="text-base font-semibold">
                  {cp.position}. {cp.title}
                </span>
                {cp.description && <p className="text-sm text-muted-foreground">{cp.description}</p>}
                <div className="mt-1 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
                  <span>Weight {cp.weight}</span>
                  {cp.due_at && <span>Due {new Date(cp.due_at).toLocaleString()}</span>}
                  {cp.requires_mr && <span>Requires MR</span>}
                  {cp.requires_ci_pass && <span>Requires CI pass</span>}
                </div>
              </div>
              <div className="flex shrink-0 items-center gap-1">
                <CheckpointDialog assignmentId={assignmentId} checkpoint={cp} />
                <DeleteCheckpointButton assignmentId={assignmentId} checkpointId={cp.id} title={cp.title} />
              </div>
            </div>

            <CheckpointSubmissions
              assignmentId={assignmentId}
              checkpoint={cp}
              requiredApprovals={requiredApprovals}
              submissions={submissionsByCheckpoint[cp.id] ?? []}
              teamsById={teamsById}
            />
          </article>
        ))
      )}
    </div>
  );
}
