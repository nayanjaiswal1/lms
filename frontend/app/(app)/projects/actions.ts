"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type {
  ApplicationStatus,
  HandoffMode,
  ProjectApplication,
  ProjectAssignment,
  ProjectCheckpoint,
  ProjectDesignProposal,
  ProjectHandoff,
  ProjectOriginalityReport,
  ProjectRequirement,
  ProjectTask,
  ProjectTeam,
  ProjectTeamCheckpoint,
  ProjectTeamMember,
  TaskStatus,
} from "@/lib/projects/types";

// ─── Assignments ─────────────────────────────────────────────────────────────

export interface CreateAssignmentInput {
  batch_id: string;
  title: string;
  slug: string;
  description?: string;
  template_project_path: string;
  // Pins the assignment to one of the org's GitLab pool entries instead of
  // following the org default — omit to follow the default. Only meaningful
  // (and only ever shown in the form) when the org's gitlab_org_config.
  // allow_project_override is true.
  installation_id?: string;
  visibility: "private" | "internal";
  required_approvals: number;
  protect_default_branch: boolean;
  default_branch: string;
  starts_at: string | null;
  due_at: string | null;
}

export async function createAssignmentAction(input: CreateAssignmentInput): Promise<ActionResult<{ id: string }>> {
  const result = await apiAction<ProjectAssignment>("POST", "/api/projects/assignments", input);
  if (!result.ok || !result.data) return { error: result.error };
  revalidatePath(ROUTES.PROJECTS);
  return { ok: true, data: { id: result.data.id } };
}

export interface UpdateAssignmentInput {
  title?: string;
  description?: string | null;
  visibility?: "private" | "internal";
  required_approvals?: number;
  protect_default_branch?: boolean;
  default_branch?: string;
  starts_at?: string | null;
  due_at?: string | null;
}

export async function updateAssignmentAction(assignmentId: string, input: UpdateAssignmentInput): Promise<ActionResult> {
  const result = await apiAction("PATCH", `/api/projects/assignments/${assignmentId}`, input);
  if (result.ok) {
    revalidatePath(ROUTES.PROJECTS);
    revalidatePath(ROUTES.projectAssignment(assignmentId));
  }
  return result;
}

// Pins (installationId set) or clears (null, reverting to the org default)
// which GitLab pool entry this assignment's teams provision against. A
// dedicated action rather than folded into updateAssignmentAction — see
// ProjectAssignment.InstallationID's own doc comment (backend models.go)
// for why the generic PATCH can't express "explicitly clear."
export async function setAssignmentInstallationAction(assignmentId: string, installationId: string | null): Promise<ActionResult<ProjectAssignment>> {
  const result = await apiAction<ProjectAssignment>("PUT", `/api/projects/assignments/${assignmentId}/installation`, {
    installation_id: installationId,
  });
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

export async function deleteAssignmentAction(assignmentId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/projects/assignments/${assignmentId}`);
  if (result.ok) revalidatePath(ROUTES.PROJECTS);
  return result;
}

export async function publishAssignmentAction(assignmentId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/projects/assignments/${assignmentId}/publish`);
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

// ─── Teams ───────────────────────────────────────────────────────────────────

export async function createTeamAction(
  assignmentId: string,
  input: { name: string; slug: string },
): Promise<ActionResult<{ id: string }>> {
  const result = await apiAction<ProjectTeam>("POST", `/api/projects/assignments/${assignmentId}/teams`, input);
  if (!result.ok || !result.data) return { error: result.error };
  revalidatePath(ROUTES.projectAssignment(assignmentId));
  return { ok: true, data: { id: result.data.id } };
}

export async function updateTeamAction(
  teamId: string,
  assignmentId: string,
  input: { name?: string; slug?: string },
): Promise<ActionResult> {
  const result = await apiAction("PATCH", `/api/projects/teams/${teamId}`, input);
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

export async function deleteTeamAction(teamId: string, assignmentId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/projects/teams/${teamId}`);
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

export async function reprovisionTeamAction(teamId: string, assignmentId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/projects/teams/${teamId}/reprovision`);
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

export async function syncTeamAction(teamId: string, assignmentId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/projects/teams/${teamId}/sync`);
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

// ─── Team members ────────────────────────────────────────────────────────────

export async function addTeamMemberAction(
  teamId: string,
  userId: string,
  assignmentId: string,
  input: { role: "lead" | "member"; gitlab_access_level: 20 | 30 | 40 },
): Promise<ActionResult<ProjectTeamMember>> {
  const result = await apiAction<ProjectTeamMember>("POST", `/api/projects/teams/${teamId}/members/${userId}`, input);
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

export async function removeTeamMemberAction(teamId: string, userId: string, assignmentId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/projects/teams/${teamId}/members/${userId}`);
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

// ─── Checkpoints (staff) ─────────────────────────────────────────────────────

export interface CheckpointInput {
  title: string;
  description?: string | null;
  position: number;
  due_at: string | null;
  weight: number;
  requires_mr: boolean;
  requires_ci_pass: boolean;
  kind?: string;
}

export async function createCheckpointAction(
  assignmentId: string,
  input: CheckpointInput,
): Promise<ActionResult<ProjectCheckpoint>> {
  const result = await apiAction<ProjectCheckpoint>(
    "POST",
    `/api/projects/assignments/${assignmentId}/checkpoints`,
    input,
  );
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

export async function updateCheckpointAction(
  checkpointId: string,
  assignmentId: string,
  input: Partial<CheckpointInput>,
): Promise<ActionResult<ProjectCheckpoint>> {
  const result = await apiAction<ProjectCheckpoint>("PATCH", `/api/projects/checkpoints/${checkpointId}`, input);
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

export async function deleteCheckpointAction(checkpointId: string, assignmentId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/projects/checkpoints/${checkpointId}`);
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

// ─── Submissions & peer review (staff) ──────────────────────────────────────

export async function gradeSubmissionAction(
  checkpointId: string,
  teamId: string,
  assignmentId: string,
  input: { score: number; feedback: string | null },
): Promise<ActionResult<ProjectTeamCheckpoint>> {
  const result = await apiAction<ProjectTeamCheckpoint>(
    "PATCH",
    `/api/projects/checkpoints/${checkpointId}/submissions/${teamId}/grade`,
    input,
  );
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

export async function mergeSubmissionAction(
  checkpointId: string,
  teamId: string,
  assignmentId: string,
): Promise<ActionResult<ProjectTeamCheckpoint>> {
  const result = await apiAction<ProjectTeamCheckpoint>(
    "POST",
    `/api/projects/checkpoints/${checkpointId}/submissions/${teamId}/merge`,
  );
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

export async function commentOnSubmissionAction(
  checkpointId: string,
  teamId: string,
  assignmentId: string,
  body: string,
): Promise<ActionResult> {
  const result = await apiAction(
    "POST",
    `/api/projects/checkpoints/${checkpointId}/submissions/${teamId}/comment`,
    { body },
  );
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

// ─── Batch 6: originality, template sync, handoff ───────────────────────────

// Enqueues gitlab.originality_scan and returns the created "pending" report —
// OriginalityReport's poller then refreshes the page until it flips to
// complete/failed. revalidatePath so the new pending row shows up immediately.
export async function runOriginalityScanAction(assignmentId: string): Promise<ActionResult<ProjectOriginalityReport>> {
  const result = await apiAction<ProjectOriginalityReport>("POST", `/api/projects/assignments/${assignmentId}/originality`);
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

// Fire-and-confirm: opens one cross-fork MR per team in the background. No
// revalidatePath — nothing on this page reflects a template sync's result,
// the MRs land directly on each team's GitLab project.
export async function runTemplateSyncAction(assignmentId: string): Promise<ActionResult> {
  return apiAction("POST", `/api/projects/assignments/${assignmentId}/template-sync`);
}

export interface HandoffInput {
  user_id: string;
  mode: HandoffMode;
  target_namespace_id: number;
  target_namespace_path?: string;
}

// Creates/resets the team's handoff and enqueues gitlab.handoff. There is no
// GET .../handoff route (see routes.go) — completion is delivered via the
// gitlab.handoff_complete notification (NotificationBell), not by re-reading
// this page, so the dialog shows this response's own "pending" snapshot only.
export async function requestHandoffAction(
  teamId: string,
  assignmentId: string,
  input: HandoffInput,
): Promise<ActionResult<ProjectHandoff>> {
  const result = await apiAction<ProjectHandoff>("POST", `/api/projects/teams/${teamId}/handoff`, input);
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

// ─── Marketplace (Phase A, Slice 1) ─────────────────────────────────────────

export interface RequirementInput {
  title: string;
  brief: string;
  required_skills: string[];
  team_size_min: number;
  team_size_max: number;
  application_deadline: string;
}

export async function createRequirementAction(input: RequirementInput): Promise<ActionResult<{ id: string }>> {
  const result = await apiAction<ProjectRequirement>("POST", "/api/project-marketplace/requirements", input);
  if (!result.ok || !result.data) return { error: result.error };
  revalidatePath(ROUTES.PROJECTS_REQUIREMENTS);
  return { ok: true, data: { id: result.data.id } };
}

export async function updateRequirementAction(
  requirementId: string,
  input: Partial<RequirementInput>,
): Promise<ActionResult<ProjectRequirement>> {
  const result = await apiAction<ProjectRequirement>("PATCH", `/api/project-marketplace/requirements/${requirementId}`, input);
  if (result.ok) revalidatePath(ROUTES.projectRequirement(requirementId));
  return result;
}

export async function publishRequirementAction(requirementId: string): Promise<ActionResult<ProjectRequirement>> {
  const result = await apiAction<ProjectRequirement>("POST", `/api/project-marketplace/requirements/${requirementId}/publish`);
  if (result.ok) {
    revalidatePath(ROUTES.projectRequirement(requirementId));
    revalidatePath(ROUTES.PROJECTS_BOARD);
  }
  return result;
}

export async function closeRequirementAction(requirementId: string): Promise<ActionResult<ProjectRequirement>> {
  const result = await apiAction<ProjectRequirement>("POST", `/api/project-marketplace/requirements/${requirementId}/close`);
  if (result.ok) {
    revalidatePath(ROUTES.projectRequirement(requirementId));
    revalidatePath(ROUTES.PROJECTS_BOARD);
  }
  return result;
}

export async function reviewApplicationAction(
  applicationId: string,
  requirementId: string,
  status: ApplicationStatus,
): Promise<ActionResult<ProjectApplication>> {
  const result = await apiAction<ProjectApplication>("PATCH", `/api/project-marketplace/applications/${applicationId}`, { status });
  if (result.ok) revalidatePath(ROUTES.projectRequirement(requirementId));
  return result;
}

export async function applyToRequirementAction(
  requirementId: string,
  motivation: string,
  resumeText: string,
): Promise<ActionResult<ProjectApplication>> {
  const result = await apiAction<ProjectApplication>("POST", `/api/project-marketplace/board/${requirementId}/apply`, {
    motivation,
    resume_text: resumeText,
  });
  if (result.ok) revalidatePath(ROUTES.boardRequirement(requirementId));
  return result;
}

export async function withdrawApplicationAction(applicationId: string, requirementId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/project-marketplace/applications/${applicationId}`);
  if (result.ok) revalidatePath(ROUTES.boardRequirement(requirementId));
  return result;
}

// ─── Batch 7 (Phase B): task board ──────────────────────────────────────────

export interface TaskInput {
  title: string;
  description?: string | null;
  checkpoint_id?: string | null;
  due_at?: string | null;
}

export async function createTaskAction(teamId: string, input: TaskInput): Promise<ActionResult<ProjectTask>> {
  const result = await apiAction<ProjectTask>("POST", `/api/projects/teams/${teamId}/tasks`, input);
  if (result.ok) revalidatePath(ROUTES.myProject(teamId));
  return result;
}

export async function updateTaskStatusAction(taskId: string, teamId: string, status: TaskStatus): Promise<ActionResult<ProjectTask>> {
  const result = await apiAction<ProjectTask>("PATCH", `/api/projects/tasks/${taskId}`, { status });
  if (result.ok) revalidatePath(ROUTES.myProject(teamId));
  return result;
}

export async function setTaskAssigneeAction(
  taskId: string,
  teamId: string,
  assigneeUserId: string | null,
): Promise<ActionResult<ProjectTask>> {
  const result = await apiAction<ProjectTask>("PUT", `/api/projects/tasks/${taskId}/assignee`, { assignee_user_id: assigneeUserId });
  if (result.ok) revalidatePath(ROUTES.myProject(teamId));
  return result;
}

export async function deleteTaskAction(taskId: string, teamId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/projects/tasks/${taskId}`);
  if (result.ok) revalidatePath(ROUTES.myProject(teamId));
  return result;
}

// ─── Batch 7 (Phase B): design proposals & voting ──────────────────────────

export interface ProposalInput {
  title: string;
  description?: string | null;
  link?: string | null;
}

export async function submitProposalAction(
  teamId: string,
  checkpointId: string,
  input: ProposalInput,
): Promise<ActionResult<ProjectDesignProposal>> {
  const result = await apiAction<ProjectDesignProposal>(
    "POST",
    `/api/projects/teams/${teamId}/checkpoints/${checkpointId}/proposals`,
    input,
  );
  if (result.ok) revalidatePath(ROUTES.myProject(teamId));
  return result;
}

export async function voteForProposalAction(proposalId: string, teamId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/projects/proposals/${proposalId}/vote`);
  if (result.ok) revalidatePath(ROUTES.myProject(teamId));
  return result;
}

export async function removeVoteAction(proposalId: string, teamId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/projects/proposals/${proposalId}/vote`);
  if (result.ok) revalidatePath(ROUTES.myProject(teamId));
  return result;
}

export async function deleteProposalAction(proposalId: string, teamId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/projects/proposals/${proposalId}`);
  if (result.ok) revalidatePath(ROUTES.myProject(teamId));
  return result;
}

// Staff-only — settles a design/architecture review checkpoint on one
// team's winning proposal.
export async function acceptProposalAction(proposalId: string, assignmentId: string): Promise<ActionResult<ProjectDesignProposal>> {
  const result = await apiAction<ProjectDesignProposal>("POST", `/api/projects/proposals/${proposalId}/accept`);
  if (result.ok) revalidatePath(ROUTES.projectAssignment(assignmentId));
  return result;
}

// Enqueues the AI scoring job — GET .../applications (revalidated below)
// won't show new scores until the background job finishes, same
// fire-and-confirm shape as runOriginalityScanAction above.
export async function requestScoringAction(requirementId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/project-marketplace/requirements/${requirementId}/score`);
  if (result.ok) revalidatePath(ROUTES.projectRequirement(requirementId));
  return result;
}

export interface CreateTeamFromSelectionInput {
  assignment_id: string;
  team_name: string;
  team_slug: string;
}

export async function createTeamFromSelectionAction(
  requirementId: string,
  input: CreateTeamFromSelectionInput,
): Promise<ActionResult<{ team: ProjectTeam; added_user_ids: string[] }>> {
  const result = await apiAction<{ team: ProjectTeam; added_user_ids: string[] }>(
    "POST",
    `/api/project-marketplace/requirements/${requirementId}/create-team`,
    input,
  );
  if (result.ok) revalidatePath(ROUTES.projectRequirement(requirementId));
  return result;
}
