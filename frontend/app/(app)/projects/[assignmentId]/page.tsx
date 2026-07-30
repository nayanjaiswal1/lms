import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import {
  getAssignmentBurndown,
  getAssignmentCheckpoints,
  getAssignmentDashboard,
  getAssignmentLeaderboard,
  getCheckpointSubmissions,
  getOriginalityReports,
  getProjectAssignment,
  getProjectTeamMembers,
  getProjectTeams,
  getTeamActivity,
} from "@/lib/projects/server";
import { getBatch, getBatchMembers } from "@/lib/server/batches";
import { PublishAssignmentButton } from "@/components/projects/publish-assignment-button";
import { EditAssignmentPanel } from "@/components/projects/edit-assignment-panel";
import { DeleteAssignmentButton } from "@/components/projects/delete-assignment-button";
import { TemplateSyncButton } from "@/components/projects/template-sync-button";
import { CreateTeamPanel } from "@/components/projects/create-team-panel";
import { TeamList } from "@/components/projects/team-list";
import { CheckpointList } from "@/components/projects/checkpoint-list";
import { OriginalityReport } from "@/components/projects/originality-report";
import { AssignmentLeaderboard } from "@/components/projects/assignment-leaderboard";
import { AssignmentBurndown } from "@/components/projects/assignment-burndown";
import { Badge } from "@/components/ui/badge";

export const metadata: Metadata = { title: "Project Assignment" };

interface PageProps {
  params: Promise<{ assignmentId: string }>;
}

const STATUS_VARIANT: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  draft:    "outline",
  active:   "default",
  archived: "secondary",
};

export default async function ProjectAssignmentPage({ params }: PageProps) {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);
  const { assignmentId } = await params;

  let assignment: Awaited<ReturnType<typeof getProjectAssignment>>;
  let teams: Awaited<ReturnType<typeof getProjectTeams>>;
  try {
    [assignment, teams] = await Promise.all([
      getProjectAssignment(assignmentId),
      getProjectTeams(assignmentId),
    ]);
  } catch {
    notFound();
  }

  const [batch, batchMembers, membersByTeam, activityByTeam, dashboard, leaderboard, burndown, checkpoints, originalityReports] = await Promise.all([
    getBatch(assignment.batch_id),
    getBatchMembers(assignment.batch_id),
    Promise.all(teams.map((t) => getProjectTeamMembers(t.id))),
    Promise.all(teams.map((t) => getTeamActivity(t.id))),
    getAssignmentDashboard(assignment.id),
    getAssignmentLeaderboard(assignment.id),
    getAssignmentBurndown(assignment.id),
    getAssignmentCheckpoints(assignment.id),
    getOriginalityReports(assignment.id),
  ]);
  const submissionsByCheckpoint = Object.fromEntries(
    await Promise.all(checkpoints.map(async (cp) => [cp.id, await getCheckpointSubmissions(cp.id)] as const)),
  );

  const assignedUserIds = new Set(membersByTeam.flat().map((m) => m.user_id));
  const availableStudents = batchMembers.filter((m) => !assignedUserIds.has(m.user_id));
  const dashboardByTeam = Object.fromEntries(dashboard.teams.map((t) => [t.team_id, t]));
  const teamsById = Object.fromEntries(teams.map((t) => [t.id, t]));

  return (
    <main className="page-container">
      <header className="page-header items-start">
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-2">
            <h1 className="page-title">{assignment.title}</h1>
            <Badge variant={STATUS_VARIANT[assignment.status] ?? "outline"}>{assignment.status}</Badge>
          </div>
          <p className="text-muted-foreground">{batch.name}</p>
          {assignment.description && <p className="max-w-2xl text-sm text-muted-foreground">{assignment.description}</p>}
          <div className="mt-1 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
            <span className="capitalize">{assignment.visibility}</span>
            <span>{assignment.required_approvals} approval{assignment.required_approvals === 1 ? "" : "s"}</span>
            <span>Branch: {assignment.default_branch}{assignment.protect_default_branch ? " (protected)" : ""}</span>
            {assignment.template_project_path && <span>Template: {assignment.template_project_path}</span>}
            {assignment.due_at && <span>Due {new Date(assignment.due_at).toLocaleString()}</span>}
          </div>
        </div>
        <div className="flex shrink-0 flex-wrap gap-2">
          {assignment.status === "draft" && <PublishAssignmentButton assignmentId={assignment.id} />}
          {assignment.status === "active" && <TemplateSyncButton assignmentId={assignment.id} />}
          <EditAssignmentPanel assignment={assignment} />
          {assignment.status === "draft" && <DeleteAssignmentButton assignmentId={assignment.id} />}
        </div>
      </header>

      <div className="mt-8 flex flex-col gap-4">
        <div className="flex items-center justify-between gap-4">
          <h2 className="section-title">Teams</h2>
          <CreateTeamPanel assignmentId={assignment.id} />
        </div>
        <TeamList
          activityByTeam={Object.fromEntries(teams.map((t, i) => [t.id, activityByTeam[i]]))}
          assignmentId={assignment.id}
          availableStudents={availableStudents}
          dashboardByTeam={dashboardByTeam}
          membersByTeam={Object.fromEntries(teams.map((t, i) => [t.id, membersByTeam[i]]))}
          teams={teams}
        />
      </div>

      <div className="mt-10 flex flex-col gap-4">
        <CheckpointList
          assignmentId={assignment.id}
          checkpoints={checkpoints}
          requiredApprovals={assignment.required_approvals}
          submissionsByCheckpoint={submissionsByCheckpoint}
          teamsById={teamsById}
        />
      </div>

      <div className="mt-10 flex flex-col gap-4">
        <h2 className="section-title">Originality</h2>
        <OriginalityReport
          assignmentId={assignment.id}
          reports={originalityReports}
          teamsById={Object.fromEntries(teams.map((t) => [t.id, t.name]))}
        />
      </div>

      <div className="mt-10 flex flex-col gap-6">
        <h2 className="section-title">Leaderboard &amp; burndown</h2>
        <div className="grid-responsive-2 grid gap-6">
          <section className="card-base flex flex-col gap-4 p-6">
            <h3 className="text-sm font-semibold">Commit leaderboard</h3>
            <AssignmentLeaderboard leaderboard={leaderboard.leaderboard} />
          </section>
          <section className="card-base flex flex-col gap-4 p-6">
            <h3 className="text-sm font-semibold">Checkpoint burndown</h3>
            <AssignmentBurndown checkpoints={burndown.checkpoints} />
          </section>
        </div>
      </div>
    </main>
  );
}
