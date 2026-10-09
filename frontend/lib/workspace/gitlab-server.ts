import "server-only";

import { apiGet } from "@/lib/server/api";
import type {
  DesignProposalView,
  MyProjectCheckpointsView,
  TeamActivityView,
  TeamContributionsView,
  TeamOwnershipView,
} from "@/lib/workspace/cohort-types";

const base = (workspaceId: string) => `/api/workspaces/${workspaceId}`;

export async function getWorkspaceGitlabActivity(workspaceId: string): Promise<TeamActivityView> {
  return apiGet<TeamActivityView>(`${base(workspaceId)}/gitlab/activity`);
}

export async function getWorkspaceContributions(workspaceId: string): Promise<TeamContributionsView> {
  return apiGet<TeamContributionsView>(`${base(workspaceId)}/gitlab/contributions`);
}

export async function getWorkspaceOwnership(workspaceId: string): Promise<TeamOwnershipView> {
  return apiGet<TeamOwnershipView>(`${base(workspaceId)}/gitlab/ownership`);
}

export async function getWorkspaceCheckpoints(workspaceId: string): Promise<MyProjectCheckpointsView> {
  return apiGet<MyProjectCheckpointsView>(`${base(workspaceId)}/checkpoints`);
}

// Member-scoped — the caller's own workspace team only.
export async function listWorkspaceProposals(workspaceId: string, checkpointId: string): Promise<DesignProposalView[]> {
  return apiGet<DesignProposalView[]>(`${base(workspaceId)}/checkpoints/${checkpointId}/proposals`);
}
