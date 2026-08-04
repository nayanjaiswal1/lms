import "server-only";

import { apiGet } from "@/lib/server/api";
import type {
  AssignmentBurndownView,
  AssignmentDashboardView,
  AssignmentLeaderboardView,
  MyProjectCheckpointsView,
  MyProjectDetailView,
  MyProjectSummary,
  OriginalityReportView,
  ProjectAssignment,
  ProjectCheckpointWithSubmissions,
  ProjectTeam,
  TeamContributionsView,
} from "@/lib/projects/types";

// GET /api/projects/assignments returns the array directly under "data" —
// unlike lib/assessments/server.ts's handlers, this domain's WriteJSON calls
// never wrap it in a named key (see handler_assignment.go / handler_team.go).

export async function getProjectAssignments(batchId?: string): Promise<ProjectAssignment[]> {
  const qs = batchId ? `?batch_id=${encodeURIComponent(batchId)}` : "";
  return apiGet<ProjectAssignment[]>(`/api/projects/assignments${qs}`);
}

export async function getProjectAssignment(assignmentId: string): Promise<ProjectAssignment> {
  return apiGet<ProjectAssignment>(`/api/projects/assignments/${assignmentId}`);
}

export async function getProjectTeams(assignmentId: string): Promise<ProjectTeam[]> {
  return apiGet<ProjectTeam[]>(`/api/projects/assignments/${assignmentId}/teams`);
}

// ─── Batch 4: staff+mentor dashboards ──────────────────────────────────────

// Each team row embeds its own member roster and activity feed (see
// TeamDashboardSummary in lib/projects/types.ts) — the assignment detail
// page reads members/activity straight off this response instead of a
// getProjectTeamMembers/getTeamActivity call per team (the N+1 those two
// single-team endpoints used to require; both endpoints still exist on the
// backend for any other single-team caller, just unused by this page now).
export async function getAssignmentDashboard(assignmentId: string): Promise<AssignmentDashboardView> {
  return apiGet<AssignmentDashboardView>(`/api/projects/assignments/${assignmentId}/dashboard`);
}

export async function getTeamContributions(teamId: string): Promise<TeamContributionsView> {
  return apiGet<TeamContributionsView>(`/api/projects/teams/${teamId}/contributions`);
}

export async function getAssignmentBurndown(assignmentId: string): Promise<AssignmentBurndownView> {
  return apiGet<AssignmentBurndownView>(`/api/projects/assignments/${assignmentId}/burndown`);
}

export async function getAssignmentLeaderboard(assignmentId: string): Promise<AssignmentLeaderboardView> {
  return apiGet<AssignmentLeaderboardView>(`/api/projects/assignments/${assignmentId}/leaderboard`);
}

// ─── Batch 4: student-facing "my projects" (row-scoped to the caller) ──────

export async function listMyProjects(): Promise<MyProjectSummary[]> {
  return apiGet<MyProjectSummary[]>(`/api/my/projects`);
}

// Returns the full ProjectTeam row (not MyProjectSummary) — see
// GetMyProject's real response shape in handler_dashboard.go. 404s for a
// team the caller doesn't belong to.
export async function getMyProject(teamId: string): Promise<ProjectTeam> {
  return apiGet<ProjectTeam>(`/api/my/projects/${teamId}`);
}

// Returns the team plus its assignment_title/role, contributions, and
// checkpoints in one response — the team detail page's full data need
// (see handler_my_project.go), instead of getMyProject + listMyProjects +
// getMyProjectContributions + getMyProjectCheckpoints. Same 404-not-403
// membership scoping as getMyProject.
export async function getMyProjectDetail(teamId: string): Promise<MyProjectDetailView> {
  return apiGet<MyProjectDetailView>(`/api/my/projects/${teamId}/detail`);
}

export async function getMyProjectContributions(teamId: string): Promise<TeamContributionsView> {
  return apiGet<TeamContributionsView>(`/api/my/projects/${teamId}/contributions`);
}

// Batch 5 (gap fix): the caller's own team's checkpoint list + submission
// status (MR state, approvals, CI, grade/feedback) — row-scoped via
// GetMyProjectCheckpoints's membership check, same as the two above.
export async function getMyProjectCheckpoints(teamId: string): Promise<MyProjectCheckpointsView> {
  return apiGet<MyProjectCheckpointsView>(`/api/my/projects/${teamId}/checkpoints`);
}

// ─── Batch 5: checkpoints & peer review (staff, admin/instructor only) ─────
// ListCheckpoints/ListSubmissions return their arrays directly under "data",
// same convention as getProjectAssignments/getProjectTeams above.

// Each checkpoint row embeds every team's submission against it
// (ProjectCheckpointWithSubmissions — see lib/projects/types.ts) — the
// assignment detail page reads submissions straight off this response
// instead of a getCheckpointSubmissions call per checkpoint (the N+1
// Promise.all(checkpoints.map(getCheckpointSubmissions)) used to make).
export async function getAssignmentCheckpoints(assignmentId: string): Promise<ProjectCheckpointWithSubmissions[]> {
  return apiGet<ProjectCheckpointWithSubmissions[]>(`/api/projects/assignments/${assignmentId}/checkpoints`);
}

// ─── Batch 6: originality scans (staff) ─────────────────────────────────────
// Each row is a report plus its own matches (OriginalityReportView) — same
// "array directly under data" convention as getAssignmentCheckpoints above.

export async function getOriginalityReports(assignmentId: string): Promise<OriginalityReportView[]> {
  return apiGet<OriginalityReportView[]>(`/api/projects/assignments/${assignmentId}/originality`);
}
