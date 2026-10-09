import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { ReprovisionTeamButton } from "@/components/workspace/cohort/reprovision-team-button";
import { PROVISION_FAILED, PROVISION_STATUS_LABEL, PROVISION_VARIANT } from "@/lib/constants";
import type { ProjectSummary } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

interface CohortWorkspaceListProps {
  cohortId: string;
  workspaces: ProjectSummary[];
}

export function CohortWorkspaceList({ cohortId, workspaces }: CohortWorkspaceListProps) {
  if (workspaces.length === 0) {
    return <p className="text-sm text-muted-foreground">No team workspaces yet.</p>;
  }

  return (
    <ul className="flex flex-col gap-3">
      {workspaces.map((w) => {
        const status = w.provision_status;
        return (
          <li className="card-base flex flex-wrap items-center justify-between gap-3 p-4" key={w.id}>
            <div className="flex min-w-0 flex-col gap-1">
              <Link className="truncate font-semibold hover:underline" href={ROUTES.workspace(w.id)}>
                {w.title}
              </Link>
              <span className="text-xs text-muted-foreground">
                {w.member_count} member{w.member_count === 1 ? "" : "s"}
              </span>
            </div>
            {w.team_id && status && (
              <div className="flex items-center gap-2">
                <Badge variant={PROVISION_VARIANT[status] ?? "outline"}>{PROVISION_STATUS_LABEL[status] ?? status}</Badge>
                {status === PROVISION_FAILED && <ReprovisionTeamButton cohortId={cohortId} teamId={w.team_id} />}
              </div>
            )}
          </li>
        );
      })}
    </ul>
  );
}
