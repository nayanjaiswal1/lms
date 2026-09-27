import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { BurndownChart } from "@/components/workspace/dashboard/burndown-chart";
import { CreateSprintDialog } from "@/components/workspace/sprints/create-sprint-dialog";
import { SprintCard } from "@/components/workspace/sprints/sprint-card";
import { getWorkspaceDashboard } from "@/lib/workspace/phase4-server";
import { listWorkspaceSprints } from "@/lib/workspace/phase5-server";
import { getWorkspace } from "@/lib/workspace/server";
import { roleAtLeast } from "@/lib/workspace/roles";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Sprints",
};

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function WorkspaceSprintsPage({ params }: PageProps) {
  const { id } = await params;
  const workspace = await getWorkspace(id);
  if (!workspace.sprints_enabled) redirect(ROUTES.workspace(id));

  const [sprints, dashboard] = await Promise.all([listWorkspaceSprints(id), getWorkspaceDashboard(id)]);
  const canManage = roleAtLeast(workspace.my_role, "manager");
  const active = sprints.find((s) => s.status === "active");
  const planned = sprints.filter((s) => s.status === "planned");
  const completed = sprints.filter((s) => s.status === "completed");

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="page-title">Sprints</h1>
        {canManage && <CreateSprintDialog workspaceId={id} />}
      </div>

      {active && (
        <div className="card-base flex flex-col gap-4">
          <div className="flex items-center justify-between">
            <h2 className="section-title">Active sprint</h2>
            {dashboard.delivery.sprint_commitment_pct !== null && (
              <span className="text-sm text-muted-foreground">
                Commitment: {(dashboard.delivery.sprint_commitment_pct * 100).toFixed(0)}%
              </span>
            )}
          </div>
          <SprintCard canManage={canManage} plannedSprints={planned} sprint={active} workspaceId={id} />
          <BurndownChart burndown={dashboard.delivery.burndown} />
        </div>
      )}

      {planned.length > 0 && (
        <div className="flex flex-col gap-3">
          <h2 className="section-title">Planned</h2>
          {planned.map((s) => (
            <SprintCard canManage={canManage} key={s.id} plannedSprints={planned} sprint={s} workspaceId={id} />
          ))}
        </div>
      )}

      {completed.length > 0 && (
        <div className="flex flex-col gap-3">
          <h2 className="section-title">Completed</h2>
          {completed.map((s) => (
            <SprintCard canManage={canManage} key={s.id} plannedSprints={planned} sprint={s} workspaceId={id} />
          ))}
        </div>
      )}

      {sprints.length === 0 && <p className="text-sm text-muted-foreground">No sprints yet.</p>}
    </div>
  );
}
