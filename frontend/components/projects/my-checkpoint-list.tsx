import { CalendarClock, ExternalLink, ListChecks } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { CHECKPOINT_STATUS_LABEL, CHECKPOINT_STATUS_VARIANT, CI_STATUS_LABEL, CI_STATUS_VARIANT } from "@/lib/constants";
import type { MyCheckpointRow } from "@/lib/projects/types";

interface MyCheckpointListProps {
  checkpoints: MyCheckpointRow[];
}

// Read-only student view of a team's checkpoints — no actions, since
// merging/grading/commenting stay staff-only (checkpoint-submissions.tsx /
// submission-row.tsx). Reuses that same file's badge/status maps from
// lib/constants.ts rather than redefining them here.
//
// ponytail: approvals show as a plain count ("2 approvals"), not "2/3" —
// required_approvals lives on ProjectAssignment, which has no student-scoped
// read route (GET /api/projects/assignments/{id} is staff-only). Add the
// denominator if a student-facing assignment summary route is ever added;
// not worth a new backend route for this one number today.
export function MyCheckpointList({ checkpoints }: MyCheckpointListProps) {
  if (checkpoints.length === 0) {
    return (
      <div className="empty-state py-10">
        <ListChecks aria-hidden className="empty-state-icon" />
        <p className="text-sm text-muted-foreground">No checkpoints have been configured for this assignment yet.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      {checkpoints.map((cp) => (
        <article className="flex flex-col gap-2 rounded-md border border-border p-4" key={cp.checkpoint_id}>
          <div className="flex flex-wrap items-start justify-between gap-2">
            <div className="min-w-0">
              <h3 className="text-sm font-semibold">{cp.title}</h3>
              {cp.description && <p className="text-xs text-muted-foreground">{cp.description}</p>}
            </div>
            <div className="flex shrink-0 flex-wrap items-center gap-1.5">
              <Badge variant={(cp.status && CHECKPOINT_STATUS_VARIANT[cp.status]) ?? "outline"}>
                {(cp.status && CHECKPOINT_STATUS_LABEL[cp.status]) ?? "Not started"}
              </Badge>
              {cp.ci_status && (
                <Badge variant={CI_STATUS_VARIANT[cp.ci_status] ?? "outline"}>{CI_STATUS_LABEL[cp.ci_status] ?? cp.ci_status}</Badge>
              )}
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
            {cp.due_at && (
              <span className="inline-flex items-center gap-1">
                <CalendarClock aria-hidden className="h-3 w-3" />
                Due {new Date(cp.due_at).toLocaleDateString()}
              </span>
            )}
            <span>Weight {cp.weight}</span>
            {cp.mr_web_url ? (
              <a className="inline-flex items-center gap-1 hover:underline" href={cp.mr_web_url} rel="noreferrer" target="_blank">
                Merge request ({cp.mr_state ?? "unknown"}) <ExternalLink aria-hidden className="h-3 w-3" />
              </a>
            ) : (
              <span>No merge request submitted yet</span>
            )}
            {cp.approvals_count !== null && (
              <span>
                {cp.approvals_count} approval{cp.approvals_count === 1 ? "" : "s"}
              </span>
            )}
          </div>

          {cp.status === "graded" && (
            <p className="text-sm">
              <span className="font-semibold text-primary">{cp.score}/100</span>
              {cp.feedback && <span className="ml-2 text-muted-foreground">{cp.feedback}</span>}
            </p>
          )}
        </article>
      ))}
    </div>
  );
}
