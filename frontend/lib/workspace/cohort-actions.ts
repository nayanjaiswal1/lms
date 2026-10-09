"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type {
  ProjectAssignment,
  ProjectCheckpoint,
  ProjectDesignProposal,
  ProjectOriginalityReport,
  ProjectTeamCheckpoint,
} from "@/lib/workspace/cohort-types";

const BASE = "/api/workspace-cohorts";
const refreshCohort = (cohortId: string) => revalidatePath(ROUTES.workspaceCohort(cohortId));

// ─── Cohorts ─────────────────────────────────────────────────────────────────

interface CreateCohortInput {
  batch_id: string;
  title: string;
  slug: string;
  description?: string;
  template_project_path: string;
  // Pins the cohort to one of the org's GitLab pool entries; omit to follow
  // the org default.
  installation_id?: string;
  visibility: "private" | "internal";
  required_approvals: number;
  protect_default_branch: boolean;
  default_branch: string;
  starts_at: string | null;
  due_at: string | null;
}

export async function createCohortAction(input: CreateCohortInput): Promise<ActionResult<{ id: string }>> {
  const result = await apiAction<ProjectAssignment>("POST", BASE, input);
  if (!result.ok || !result.data) return { error: result.error };
  revalidatePath(ROUTES.WORKSPACES_COHORTS);
  return { ok: true, data: { id: result.data.id } };
}

interface UpdateCohortInput {
  title?: string;
  description?: string | null;
  visibility?: "private" | "internal";
  required_approvals?: number;
  protect_default_branch?: boolean;
  default_branch?: string;
  starts_at?: string | null;
  due_at?: string | null;
}

export async function updateCohortAction(cohortId: string, input: UpdateCohortInput): Promise<ActionResult> {
  const result = await apiAction("PATCH", `${BASE}/${cohortId}`, input);
  if (result.ok) {
    revalidatePath(ROUTES.WORKSPACES_COHORTS);
    refreshCohort(cohortId);
  }
  return result;
}

// Pins (installationId set) or clears (null → org default) the GitLab pool
// entry; separate from updateCohortAction because PATCH can't express "clear".
export async function setCohortInstallationAction(cohortId: string, installationId: string | null): Promise<ActionResult<ProjectAssignment>> {
  const result = await apiAction<ProjectAssignment>("PUT", `${BASE}/${cohortId}/installation`, { installation_id: installationId });
  if (result.ok) refreshCohort(cohortId);
  return result;
}

export async function deleteCohortAction(cohortId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `${BASE}/${cohortId}`);
  if (result.ok) revalidatePath(ROUTES.WORKSPACES_COHORTS);
  return result;
}

export async function publishCohortAction(cohortId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `${BASE}/${cohortId}/publish`);
  if (result.ok) refreshCohort(cohortId);
  return result;
}

// Creates a team workspace inside the cohort.
export async function createCohortWorkspaceAction(
  cohortId: string,
  input: { title: string; member_user_ids: string[] },
): Promise<ActionResult<{ id: string }>> {
  const result = await apiAction<{ id: string }>("POST", `${BASE}/${cohortId}/workspaces`, input);
  if (result.ok) refreshCohort(cohortId);
  return result;
}

// ─── Teams ───────────────────────────────────────────────────────────────────

export async function reprovisionCohortTeamAction(teamId: string, cohortId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `${BASE}/teams/${teamId}/reprovision`);
  if (result.ok) refreshCohort(cohortId);
  return result;
}

// ─── Checkpoints (staff) ─────────────────────────────────────────────────────

interface CheckpointInput {
  title: string;
  description?: string | null;
  position: number;
  due_at: string | null;
  weight: number;
  requires_mr: boolean;
  requires_ci_pass: boolean;
  kind?: string;
}

export async function createCohortCheckpointAction(cohortId: string, input: CheckpointInput): Promise<ActionResult<ProjectCheckpoint>> {
  const result = await apiAction<ProjectCheckpoint>("POST", `${BASE}/${cohortId}/checkpoints`, input);
  if (result.ok) refreshCohort(cohortId);
  return result;
}

export async function updateCohortCheckpointAction(
  checkpointId: string,
  cohortId: string,
  input: Partial<CheckpointInput>,
): Promise<ActionResult<ProjectCheckpoint>> {
  const result = await apiAction<ProjectCheckpoint>("PATCH", `${BASE}/checkpoints/${checkpointId}`, input);
  if (result.ok) refreshCohort(cohortId);
  return result;
}

export async function deleteCohortCheckpointAction(checkpointId: string, cohortId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `${BASE}/checkpoints/${checkpointId}`);
  if (result.ok) refreshCohort(cohortId);
  return result;
}

// ─── Submissions & peer review (staff) ──────────────────────────────────────

export async function gradeCohortSubmissionAction(
  checkpointId: string,
  teamId: string,
  cohortId: string,
  input: { score: number; feedback: string | null },
): Promise<ActionResult<ProjectTeamCheckpoint>> {
  const result = await apiAction<ProjectTeamCheckpoint>("PATCH", `${BASE}/checkpoints/${checkpointId}/submissions/${teamId}/grade`, input);
  if (result.ok) refreshCohort(cohortId);
  return result;
}

export async function mergeCohortSubmissionAction(
  checkpointId: string,
  teamId: string,
  cohortId: string,
): Promise<ActionResult<ProjectTeamCheckpoint>> {
  const result = await apiAction<ProjectTeamCheckpoint>("POST", `${BASE}/checkpoints/${checkpointId}/submissions/${teamId}/merge`);
  if (result.ok) refreshCohort(cohortId);
  return result;
}

export async function commentOnCohortSubmissionAction(
  checkpointId: string,
  teamId: string,
  cohortId: string,
  body: string,
): Promise<ActionResult> {
  const result = await apiAction("POST", `${BASE}/checkpoints/${checkpointId}/submissions/${teamId}/comment`, { body });
  if (result.ok) refreshCohort(cohortId);
  return result;
}

// Staff-only — settles a design/architecture review checkpoint on one team's
// winning proposal.
export async function acceptCohortProposalAction(proposalId: string, cohortId: string): Promise<ActionResult<ProjectDesignProposal>> {
  const result = await apiAction<ProjectDesignProposal>("POST", `${BASE}/proposals/${proposalId}/accept`);
  if (result.ok) refreshCohort(cohortId);
  return result;
}

// ─── Originality & template sync ────────────────────────────────────────────

// Enqueues the scan and returns the created "pending" report.
export async function runCohortOriginalityScanAction(cohortId: string): Promise<ActionResult<ProjectOriginalityReport>> {
  const result = await apiAction<ProjectOriginalityReport>("POST", `${BASE}/${cohortId}/originality`);
  if (result.ok) refreshCohort(cohortId);
  return result;
}

// Fire-and-confirm: MRs land directly on each team's GitLab project.
export async function runCohortTemplateSyncAction(cohortId: string): Promise<ActionResult> {
  return apiAction("POST", `${BASE}/${cohortId}/template-sync`);
}
