import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";

import ROUTES from "@/lib/routes";
import { requireAccess } from "@/lib/server/features";
import { getMyPermissions } from "@/lib/server/permissions";
import { FEATURES } from "@/lib/features";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import {
  getCohort,
  getCohortBurndown,
  getCohortCheckpoints,
  getCohortDashboard,
  getCohortLeaderboard,
  getCohortOriginalityReports,
  getCohortOwnership,
  getCohortTeams,
  listAllDesignProposals,
} from "@/lib/workspace/cohort-server";
import { listCohortWorkspaces } from "@/lib/workspace/server";
import { getBatch, getBatchMembers } from "@/lib/server/batches";
import { PublishAssignmentButton } from "@/components/workspace/cohort/publish-assignment-button";
import { EditAssignmentPanel } from "@/components/workspace/cohort/edit-assignment-panel";
import { DeleteAssignmentButton } from "@/components/workspace/cohort/delete-assignment-button";
import { TemplateSyncButton } from "@/components/workspace/cohort/template-sync-button";
import { CreateTeamWorkspaceDialog } from "@/components/workspace/cohort/create-team-workspace-dialog";
import { CohortWorkspaceList } from "@/components/workspace/cohort/cohort-workspace-list";
import { CheckpointList } from "@/components/workspace/cohort/checkpoint-list";
import { OriginalityReport } from "@/components/workspace/cohort/originality-report";
import { AssignmentLeaderboard } from "@/components/workspace/cohort/assignment-leaderboard";
import { AssignmentBurndown } from "@/components/workspace/cohort/assignment-burndown";
import { OwnershipTable } from "@/components/workspace/gitlab/ownership-table";
import { AssignmentTabs } from "@/components/workspace/cohort/assignment-tabs";
import { Badge } from "@/components/ui/badge";
import { Breadcrumb } from "@/components/shared/breadcrumb";

export const metadata: Metadata = { title: "Cohort" };

interface PageProps {
  params: Promise<{ cohortId: string }>;
}

const STATUS_VARIANT: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  draft:    "outline",
  active:   "default",
  archived: "secondary",
};

export default async function CohortPage({ params }: PageProps) {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);
  const permissions = await getMyPermissions();
  if (!permissions.includes(PERMISSIONS.PROJECTS.MANAGE)) redirect(ROUTES.WORKSPACES);
  const { cohortId } = await params;

  let cohort: Awaited<ReturnType<typeof getCohort>>;
  let teams: Awaited<ReturnType<typeof getCohortTeams>>;
  try {
    [cohort, teams] = await Promise.all([getCohort(cohortId), getCohortTeams(cohortId)]);
  } catch {
    notFound();
  }

  const [batch, batchMembers, dashboard, leaderboard, burndown, checkpoints, originalityReports, workspaces, ownership] = await Promise.all([
    getBatch(cohort.batch_id),
    getBatchMembers(cohort.batch_id),
    getCohortDashboard(cohort.id),
    getCohortLeaderboard(cohort.id),
    getCohortBurndown(cohort.id),
    getCohortCheckpoints(cohort.id),
    getCohortOriginalityReports(cohort.id),
    listCohortWorkspaces(cohort.id),
    getCohortOwnership(cohort.id),
  ]);

  const submissionsByCheckpoint = Object.fromEntries(checkpoints.map((cp) => [cp.id, cp.submissions]));

  // design_review/architecture_review checkpoints are settled by proposal
  // voting, not an MR submission.
  const proposalCheckpoints = checkpoints.filter((cp) => cp.kind === "design_review" || cp.kind === "architecture_review");
  const proposalLists = await Promise.all(proposalCheckpoints.map((cp) => listAllDesignProposals(cp.id)));
  const proposalsByCheckpoint = Object.fromEntries(proposalCheckpoints.map((cp, i) => [cp.id, proposalLists[i]]));

  const assignedUserIds = new Set(dashboard.teams.flatMap((t) => t.members).map((m) => m.user_id));
  const availableStudents = batchMembers.filter((m) => !assignedUserIds.has(m.user_id));
  const ownershipByTeam = Object.fromEntries(ownership.teams.map((o) => [o.team_id, o.files]));
  const teamsById = Object.fromEntries(teams.map((t) => [t.id, t]));

  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Cohorts", href: ROUTES.WORKSPACES_COHORTS }, { label: cohort.title }]} />
      <header className="page-header items-start">
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-2">
            <h1 className="section-title">{cohort.title}</h1>
            <Badge variant={STATUS_VARIANT[cohort.status] ?? "outline"}>{cohort.status}</Badge>
          </div>
          <p className="text-muted-foreground">{batch.name}</p>
          {cohort.description && <p className="max-w-2xl text-sm text-muted-foreground">{cohort.description}</p>}
          <div className="mt-1 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
            <span className="capitalize">{cohort.visibility}</span>
            <span>{cohort.required_approvals} approval{cohort.required_approvals === 1 ? "" : "s"}</span>
            <span>Branch: {cohort.default_branch}{cohort.protect_default_branch ? " (protected)" : ""}</span>
            {cohort.template_project_path && <span>Template: {cohort.template_project_path}</span>}
            {cohort.due_at && <span>Due {new Date(cohort.due_at).toLocaleString()}</span>}
          </div>
        </div>
        <div className="flex shrink-0 flex-wrap gap-2">
          {cohort.status === "draft" && <PublishAssignmentButton assignmentId={cohort.id} />}
          {cohort.status === "active" && <TemplateSyncButton assignmentId={cohort.id} />}
          <EditAssignmentPanel assignment={cohort} />
          {cohort.status === "draft" && <DeleteAssignmentButton assignmentId={cohort.id} />}
        </div>
      </header>

      <AssignmentTabs
        checkpointCount={checkpoints.length}
        checkpointsTab={
          <CheckpointList
            assignmentId={cohort.id}
            checkpoints={checkpoints}
            proposalsByCheckpoint={proposalsByCheckpoint}
            requiredApprovals={cohort.required_approvals}
            submissionsByCheckpoint={submissionsByCheckpoint}
            teamsById={teamsById}
          />
        }
        insightsTab={
          <div className="grid-responsive-2 grid gap-6">
            <section className="card-base flex flex-col gap-4 p-6">
              <h3 className="text-sm font-semibold">Commit leaderboard</h3>
              <AssignmentLeaderboard leaderboard={leaderboard.leaderboard} />
            </section>
            <section className="card-base flex flex-col gap-4 p-6">
              <h3 className="text-sm font-semibold">Checkpoint burndown</h3>
              <AssignmentBurndown checkpoints={burndown.checkpoints} />
            </section>
            <section className="card-base flex flex-col gap-4 p-6 sm:col-span-2">
              <h3 className="text-sm font-semibold">File ownership by team</h3>
              {teams.length === 0 ? (
                <p className="text-sm text-muted-foreground">No teams yet.</p>
              ) : (
                <div className="flex flex-col gap-6">
                  {teams.map((t) => (
                    <div className="flex flex-col gap-2" key={t.id}>
                      <span className="text-xs font-semibold text-muted-foreground">{t.name}</span>
                      <OwnershipTable files={ownershipByTeam[t.id] ?? []} />
                    </div>
                  ))}
                </div>
              )}
            </section>
          </div>
        }
        originalityTab={
          <OriginalityReport
            assignmentId={cohort.id}
            reports={originalityReports}
            teamsById={Object.fromEntries(teams.map((t) => [t.id, t.name]))}
          />
        }
        teamCount={workspaces.items.length}
        teamsTab={
          <div className="flex flex-col gap-4">
            <div className="flex-between gap-4">
              <p className="text-sm text-muted-foreground">
                {workspaces.items.length} team workspace{workspaces.items.length === 1 ? "" : "s"} · {availableStudents.length} unassigned student
                {availableStudents.length === 1 ? "" : "s"}
              </p>
              <CreateTeamWorkspaceDialog availableStudents={availableStudents} cohortId={cohort.id} />
            </div>
            <CohortWorkspaceList cohortId={cohort.id} workspaces={workspaces.items} />
          </div>
        }
      />
    </main>
  );
}
