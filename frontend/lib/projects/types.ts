// Shared types for the GitLab project-assignment domain (Batch 2: teams &
// provisioning). These mirror backend/internal/gitlab/models.go exactly —
// see handler_assignment.go / handler_team.go for the request/response
// shapes this was verified against.

export type ProjectVisibility = "private" | "internal";
export type ProjectAssignmentStatus = "draft" | "active" | "archived";
export type TeamProvisionStatus = "pending" | "provisioning" | "ready" | "failed";
export type TeamMemberRole = "lead" | "member";
export type TeamMemberSyncStatus = "pending" | "synced" | "failed" | "removing";
export type GitlabAccessLevel = 20 | 30 | 40;

export interface ProjectAssignment {
  id: string;
  org_id: string;
  batch_id: string;
  course_id: string | null;
  lab_id: string | null;
  title: string;
  slug: string;
  description: string | null;
  template_project_id: number | null;
  template_project_path: string | null;
  gitlab_group_id: number | null;
  gitlab_group_path: string | null;
  installation_id: string | null;
  visibility: ProjectVisibility;
  required_approvals: number;
  protect_default_branch: boolean;
  default_branch: string;
  starts_at: string | null;
  due_at: string | null;
  status: ProjectAssignmentStatus;
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface ProjectTeam {
  id: string;
  org_id: string;
  assignment_id: string;
  name: string;
  slug: string;
  gitlab_project_id: number | null;
  gitlab_project_path: string | null;
  gitlab_web_url: string | null;
  gitlab_hook_id: number | null;
  pages_url: string | null;
  provision_status: TeamProvisionStatus;
  provision_error: string | null;
  provisioned_at: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface ProjectTeamMember {
  team_id: string;
  user_id: string;
  assignment_id: string;
  role: TeamMemberRole;
  gitlab_access_level: GitlabAccessLevel;
  sync_status: TeamMemberSyncStatus;
  sync_error: string | null;
  synced_at: string | null;
  added_by: string | null;
  added_at: string;
  // Populated only by ListTeamMembers' joined query.
  name?: string;
  email?: string;
}

// Batch 3 add-on: read-only team activity feed (GET
// /api/projects/teams/{teamID}/activity) — see backend/internal/gitlab/
// models.go's own "Batch 3 add-on" section for why these are a narrower
// projection than the full mirrored gitlab_commits/gitlab_merge_requests/
// gitlab_pipelines rows.
export type MergeRequestState = "opened" | "merged" | "closed" | "locked";

export interface TeamActivityCommit {
  sha: string;
  message: string | null;
  author_name: string | null;
  committed_at: string | null;
}

export interface TeamActivityMergeRequest {
  title: string;
  state: MergeRequestState;
  web_url: string | null;
  approvals_count: number;
}

export interface TeamActivityPipeline {
  // GitLab's pipeline status enum (created/pending/running/success/failed/
  // canceled/skipped/manual/scheduled/...) isn't pinned to a union here — the
  // backend has no CHECK constraint on it either, so a new GitLab status
  // value shows up as plain text rather than a type error.
  status: string;
  web_url: string | null;
}

export interface TeamActivityView {
  commits: TeamActivityCommit[];
  merge_requests: TeamActivityMergeRequest[];
  pipeline: TeamActivityPipeline | null;
}

// Batch 4: contribution tracking & dashboards — mirrors backend/internal/
// gitlab/models.go's own "Batch 4" section exactly. No rollup table backs
// these; every view is a direct aggregation read (see repo_dashboard.go).

export interface ContributionRow {
  user_id: string;
  name: string;
  email: string;
  commit_count: number;
  additions: number;
  deletions: number;
  last_commit_at: string | null;
  is_free_rider: boolean;
}

// GET /api/projects/teams/{teamID}/contributions (staff+mentor) and
// GET /api/my/projects/{teamID}/contributions (row-scoped student).
export interface TeamContributionsView {
  team_id: string;
  contributions: ContributionRow[];
}

// One student's ranked commit totals across every team under an assignment —
// note this shape has no is_free_rider field of its own (unlike
// ContributionRow above); the same "zero commits" signal is derived from
// commit_count === 0 where the leaderboard needs to show it.
export interface LeaderboardRow {
  rank: number;
  user_id: string;
  name: string;
  email: string;
  team_id: string;
  team_name: string;
  commit_count: number;
  additions: number;
  deletions: number;
}

export interface AssignmentLeaderboardView {
  assignment_id: string;
  leaderboard: LeaderboardRow[];
}

// One checkpoint's issue open/close tally. Correctly empty until Batch 5
// wires up checkpoint CRUD and milestone->checkpoint issue mapping — not a
// bug, nothing to match yet (see backend's own doc comment on this type).
export interface BurndownCheckpoint {
  checkpoint_id: string;
  title: string;
  position: number;
  due_at: string | null;
  total_issues: number;
  open_issues: number;
  closed_issues: number;
}

export interface AssignmentBurndownView {
  assignment_id: string;
  checkpoints: BurndownCheckpoint[];
}

// One team's rolled-up commit/MR/pipeline/free-rider summary — the
// assignment-wide, aggregated counterpart to TeamActivityView above (which
// stays unaggregated recent-activity, on purpose).
export interface TeamDashboardSummary {
  team_id: string;
  team_name: string;
  member_count: number;
  commit_count: number;
  open_mr_count: number;
  merged_mr_count: number;
  latest_pipeline_status: string | null;
  free_rider_count: number;
}

export interface AssignmentDashboardView {
  assignment_id: string;
  teams: TeamDashboardSummary[];
}

// One row of GET /api/my/projects — the authenticated student's own team
// memberships only. Distinct from ProjectTeam above: GET /api/my/projects/
// {teamID} (GetMyProject) returns the full ProjectTeam row instead, so a
// team-detail page needs both to get assignment_title/role alongside it.
export interface MyProjectSummary {
  team_id: string;
  team_name: string;
  assignment_id: string;
  assignment_title: string;
  role: TeamMemberRole;
  provision_status: TeamProvisionStatus;
  gitlab_web_url: string | null;
  pages_url: string | null;
}

// ─── Batch 5: checkpoints & peer review ────────────────────────────────────
// Mirrors backend/internal/gitlab/models.go's own "Batch 5" section exactly —
// verified directly against models.go/handler_checkpoint.go, not guessed.
// required_approvals lives on ProjectAssignment above, not on
// ProjectCheckpoint — there is no such column on project_checkpoints.

export type CheckpointStatus = "open" | "submitted" | "approved" | "merged" | "graded";
export type CIStatus = "none" | "pending" | "running" | "success" | "failed" | "canceled";

export interface ProjectCheckpoint {
  id: string;
  org_id: string;
  assignment_id: string;
  title: string;
  description: string | null;
  position: number;
  due_at: string | null;
  weight: number;
  requires_mr: boolean;
  requires_ci_pass: boolean;
  gitlab_milestone_id: number | null;
  created_at: string;
  updated_at: string;
}

// One team's submission state against one checkpoint — MR-as-submission, CI
// result, approval count, and grade all live on this one row.
export interface ProjectTeamCheckpoint {
  id: string;
  org_id: string;
  team_id: string;
  checkpoint_id: string;
  mr_iid: number | null;
  mr_id: number | null;
  mr_web_url: string | null;
  mr_state: MergeRequestState | null;
  approvals_count: number;
  ci_status: CIStatus;
  ci_pipeline_id: number | null;
  snapshot_sha: string | null;
  snapshot_at: string | null;
  is_late: boolean;
  late_commit_count: number;
  score: number | null;
  feedback: string | null;
  graded_by: string | null;
  graded_at: string | null;
  status: CheckpointStatus;
  created_at: string;
  updated_at: string;
}

// ─── Batch 5 (gap fix): student-facing "my checkpoints" ────────────────────
// Every checkpoint/submission route above is staff-only. This is the
// student-scoped read: a checkpoint's own fields, LEFT JOINed against the
// caller's team's own submission row — mirrors backend's MyCheckpointRow.
// Submission fields are null until the team has submitted against this
// checkpoint (no row yet), never a stand-in zero value.

export interface MyCheckpointRow {
  checkpoint_id: string;
  title: string;
  description: string | null;
  position: number;
  due_at: string | null;
  weight: number;
  requires_mr: boolean;
  requires_ci_pass: boolean;
  mr_web_url: string | null;
  mr_state: MergeRequestState | null;
  approvals_count: number | null;
  ci_status: CIStatus | null;
  score: number | null;
  feedback: string | null;
  status: CheckpointStatus | null;
}

export interface MyProjectCheckpointsView {
  team_id: string;
  checkpoints: MyCheckpointRow[];
}

// ─── Batch 6: originality + handoff ────────────────────────────────────────
// Mirrors backend/internal/gitlab/models.go's own "Batch 6" section exactly.

export type OriginalityReportStatus = "pending" | "running" | "complete" | "failed";

export interface ProjectOriginalityReport {
  id: string;
  org_id: string;
  assignment_id: string;
  status: OriginalityReportStatus;
  teams_scanned: number;
  files_scanned: number;
  error: string | null;
  requested_by: string | null;
  requested_at: string;
  completed_at: string | null;
}

// One file-pair whose Jaccard similarity crossed the backend's threshold
// (0.6 — see originality.go's originalityMatchThreshold). team_b_id null
// means the match is against the assignment's template project, not another
// team.
export interface ProjectOriginalityMatch {
  id: string;
  report_id: string;
  team_a_id: string;
  team_b_id: string | null;
  file_path_a: string;
  file_path_b: string;
  similarity: number;
  matched_lines: number | null;
  sample: string | null;
}

// GET .../originality's response row — Go embeds ProjectOriginalityReport's
// fields directly (untagged struct embedding), so this flattens the same way
// on the wire; matches is the only field added on top.
export interface OriginalityReportView extends ProjectOriginalityReport {
  matches: ProjectOriginalityMatch[];
}

export type HandoffMode = "fork" | "transfer";
export type HandoffStatus = "pending" | "running" | "complete" | "failed";

export interface ProjectHandoff {
  id: string;
  org_id: string;
  team_id: string;
  user_id: string;
  mode: HandoffMode;
  target_namespace_id: number | null;
  target_namespace_path: string | null;
  new_project_id: number | null;
  new_web_url: string | null;
  status: HandoffStatus;
  error: string | null;
  requested_at: string;
  completed_at: string | null;
}
