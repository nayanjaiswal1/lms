"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { HandoffMode, ProjectDesignProposal, ProjectHandoff } from "@/lib/workspace/cohort-types";

const base = (workspaceId: string) => `/api/workspaces/${workspaceId}`;
const refresh = (workspaceId: string) => revalidatePath(ROUTES.workspace(workspaceId));

interface ProposalInput {
  title: string;
  description?: string | null;
  link?: string | null;
}

export async function submitWorkspaceProposalAction(
  workspaceId: string,
  checkpointId: string,
  input: ProposalInput,
): Promise<ActionResult<ProjectDesignProposal>> {
  const result = await apiAction<ProjectDesignProposal>("POST", `${base(workspaceId)}/checkpoints/${checkpointId}/proposals`, input);
  if (result.ok) refresh(workspaceId);
  return result;
}

export async function voteForWorkspaceProposalAction(workspaceId: string, proposalId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `${base(workspaceId)}/proposals/${proposalId}/vote`);
  if (result.ok) refresh(workspaceId);
  return result;
}

export async function removeWorkspaceVoteAction(workspaceId: string, proposalId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `${base(workspaceId)}/proposals/${proposalId}/vote`);
  if (result.ok) refresh(workspaceId);
  return result;
}

export async function deleteWorkspaceProposalAction(workspaceId: string, proposalId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `${base(workspaceId)}/proposals/${proposalId}`);
  if (result.ok) refresh(workspaceId);
  return result;
}

interface HandoffInput {
  mode: HandoffMode;
  target_namespace_id: number;
  target_namespace_path: string;
}

// Completion arrives via the gitlab.handoff_complete notification; the
// response is only the "pending" snapshot.
export async function requestWorkspaceHandoffAction(workspaceId: string, input: HandoffInput): Promise<ActionResult<ProjectHandoff>> {
  const result = await apiAction<ProjectHandoff>("POST", `${base(workspaceId)}/gitlab/handoff`, input);
  if (result.ok) refresh(workspaceId);
  return result;
}
