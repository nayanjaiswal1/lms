"use server";

import { revalidatePath } from "next/cache";
import { apiAction, apiActionPublic } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type {
  CreateProjectInput,
  Member,
  OnboardingStep,
  Project,
  ProjectRole,
  ProjectStatus,
  RequirementView,
  ReviewInterestResult,
  SubmitInterestInput,
  Track,
  UpdateProjectInput,
} from "@/lib/workspace/types";

// ── Request-body shapes the contract names but that types.ts (lead-owned)
// doesn't declare. ──────────────────────────

interface SetStatusInput {
  status: ProjectStatus;
}

interface TransferOwnerInput {
  user_id: string;
}

interface ReviewInterestInput {
  decision: "accept" | "reject";
}

interface AddMemberInput {
  email: string;
  role: "member" | "viewer" | "manager";
}

interface UpdateMemberRoleInput {
  role: ProjectRole;
}

interface RespondInviteInput {
  accept: boolean;
}

interface TrackInput {
  name: string;
  lead_user_id?: string | null;
}

interface TrackMembershipInput {
  user_id: string;
}

interface OnboardingStepInput {
  title: string;
  wiki_page_id?: string | null;
  required: boolean;
  position: number;
}

interface OnboardingStepDoneInput {
  done: boolean;
}

// ── Projects ─────────────────────────────────────────────────────────────────

export async function createWorkspaceAction(input: CreateProjectInput): Promise<ActionResult<Project>> {
  const result = await apiAction<Project>("POST", "/api/workspaces", input);
  if (result.ok) revalidatePath(ROUTES.WORKSPACES);
  return result;
}

export async function updateWorkspaceAction(workspaceId: string, input: UpdateProjectInput): Promise<ActionResult<Project>> {
  const result = await apiAction<Project>("PATCH", `/api/workspaces/${workspaceId}`, input);
  if (result.ok) {
    revalidatePath(ROUTES.workspace(workspaceId));
    revalidatePath(ROUTES.workspaceSettings(workspaceId));
  }
  return result;
}

export async function setWorkspaceStatusAction(workspaceId: string, status: ProjectStatus): Promise<ActionResult<Project>> {
  const result = await apiAction<Project>("PATCH", `/api/workspaces/${workspaceId}/status`, { status } satisfies SetStatusInput);
  if (result.ok) {
    revalidatePath(ROUTES.workspace(workspaceId));
    revalidatePath(ROUTES.WORKSPACES);
  }
  return result;
}

export async function rotateShareTokenAction(workspaceId: string): Promise<ActionResult<{ share_token: string }>> {
  const result = await apiAction<{ share_token: string }>("POST", `/api/workspaces/${workspaceId}/share-token`);
  if (result.ok) revalidatePath(ROUTES.workspaceSettings(workspaceId));
  return result;
}

export async function transferOwnerAction(workspaceId: string, toUserId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/workspaces/${workspaceId}/transfer-owner`, { user_id: toUserId } satisfies TransferOwnerInput);
  if (result.ok) {
    revalidatePath(ROUTES.workspace(workspaceId));
    revalidatePath(ROUTES.workspaceSettings(workspaceId));
    revalidatePath(ROUTES.workspaceMembers(workspaceId));
  }
  return result;
}

// ── Requirement ──────────────────────────────────────────────────────────────

export async function updateRequirementAction(workspaceId: string, requirement: string): Promise<ActionResult<RequirementView>> {
  const result = await apiAction<RequirementView>("PUT", `/api/workspaces/${workspaceId}/requirement`, { requirement });
  if (result.ok) revalidatePath(ROUTES.workspaceRequirement(workspaceId));
  return result;
}

// ── Interests ────────────────────────────────────────────────────────────────

export async function acceptInterestAction(workspaceId: string, interestId: string): Promise<ActionResult<ReviewInterestResult>> {
  const result = await apiAction<ReviewInterestResult>(
    "PATCH",
    `/api/workspaces/${workspaceId}/interests/${interestId}`,
    { decision: "accept" } satisfies ReviewInterestInput,
  );
  if (result.ok) {
    revalidatePath(ROUTES.workspaceInterests(workspaceId));
    revalidatePath(ROUTES.workspace(workspaceId));
  }
  return result;
}

export async function rejectInterestAction(workspaceId: string, interestId: string): Promise<ActionResult<ReviewInterestResult>> {
  const result = await apiAction<ReviewInterestResult>(
    "PATCH",
    `/api/workspaces/${workspaceId}/interests/${interestId}`,
    { decision: "reject" } satisfies ReviewInterestInput,
  );
  if (result.ok) revalidatePath(ROUTES.workspaceInterests(workspaceId));
  return result;
}


// ── Members ──────────────────────────────────────────────────────────────────

export async function addMemberAction(workspaceId: string, input: AddMemberInput): Promise<ActionResult<Member>> {
  const result = await apiAction<Member>("POST", `/api/workspaces/${workspaceId}/members`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceMembers(workspaceId));
  return result;
}

export async function updateMemberRoleAction(workspaceId: string, userId: string, role: ProjectRole): Promise<ActionResult<Member>> {
  const result = await apiAction<Member>(
    "PATCH",
    `/api/workspaces/${workspaceId}/members/${userId}`,
    { role } satisfies UpdateMemberRoleInput,
  );
  if (result.ok) revalidatePath(ROUTES.workspaceMembers(workspaceId));
  return result;
}

export async function removeMemberAction(workspaceId: string, userId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/workspaces/${workspaceId}/members/${userId}`);
  if (result.ok) {
    revalidatePath(ROUTES.workspaceMembers(workspaceId));
    revalidatePath(ROUTES.workspace(workspaceId));
  }
  return result;
}

export async function respondToWorkspaceInviteAction(workspaceId: string, accept: boolean): Promise<ActionResult> {
  const result = await apiAction(
    "POST",
    `/api/workspaces/${workspaceId}/membership/respond`,
    { accept } satisfies RespondInviteInput,
  );
  if (result.ok) revalidatePath(ROUTES.WORKSPACES);
  return result;
}

// ── Tracks ───────────────────────────────────────────────────────────────────

export async function createTrackAction(workspaceId: string, input: TrackInput): Promise<ActionResult<Track>> {
  const result = await apiAction<Track>("POST", `/api/workspaces/${workspaceId}/tracks`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceTracks(workspaceId));
  return result;
}

export async function updateTrackAction(workspaceId: string, trackId: string, input: Partial<TrackInput>): Promise<ActionResult<Track>> {
  const result = await apiAction<Track>("PATCH", `/api/workspaces/${workspaceId}/tracks/${trackId}`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceTracks(workspaceId));
  return result;
}

export async function deleteTrackAction(workspaceId: string, trackId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/workspaces/${workspaceId}/tracks/${trackId}`);
  if (result.ok) revalidatePath(ROUTES.workspaceTracks(workspaceId));
  return result;
}

export async function joinTrackAction(workspaceId: string, trackId: string, userId: string): Promise<ActionResult> {
  const result = await apiAction(
    "POST",
    `/api/workspaces/${workspaceId}/tracks/${trackId}/members`,
    { user_id: userId } satisfies TrackMembershipInput,
  );
  if (result.ok) revalidatePath(ROUTES.workspaceTracks(workspaceId));
  return result;
}

export async function approveTrackMemberAction(workspaceId: string, trackId: string, userId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/workspaces/${workspaceId}/tracks/${trackId}/members/${userId}/approve`);
  if (result.ok) revalidatePath(ROUTES.workspaceTracks(workspaceId));
  return result;
}

export async function removeTrackMemberAction(workspaceId: string, trackId: string, userId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/workspaces/${workspaceId}/tracks/${trackId}/members/${userId}`);
  if (result.ok) revalidatePath(ROUTES.workspaceTracks(workspaceId));
  return result;
}

// ── Onboarding ───────────────────────────────────────────────────────────────

export async function createOnboardingStepAction(workspaceId: string, input: OnboardingStepInput): Promise<ActionResult<OnboardingStep>> {
  const result = await apiAction<OnboardingStep>("POST", `/api/workspaces/${workspaceId}/onboarding`, input);
  if (result.ok) revalidatePath(ROUTES.workspaceOnboarding(workspaceId));
  return result;
}


export async function deleteOnboardingStepAction(workspaceId: string, stepId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/workspaces/${workspaceId}/onboarding/${stepId}`);
  if (result.ok) revalidatePath(ROUTES.workspaceOnboarding(workspaceId));
  return result;
}

export async function setOnboardingStepDoneAction(workspaceId: string, stepId: string, done: boolean): Promise<ActionResult> {
  const result = await apiAction(
    "PUT",
    `/api/workspaces/${workspaceId}/onboarding/${stepId}/done`,
    { done } satisfies OnboardingStepDoneInput,
  );
  if (result.ok) {
    revalidatePath(ROUTES.workspaceOnboarding(workspaceId));
    revalidatePath(ROUTES.workspace(workspaceId));
  }
  return result;
}

// ── Public interest form ─────────────────────────────────────────────────────

export async function submitWorkspaceInterestAction(
  shareToken: string,
  input: SubmitInterestInput,
): Promise<ActionResult<{ message: string }>> {
  return apiActionPublic<{ message: string }>("POST", `/api/public/workspaces/${shareToken}/interest`, input);
}
