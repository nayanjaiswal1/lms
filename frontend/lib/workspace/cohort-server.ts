import "server-only";

import { apiGet } from "@/lib/server/api";
import type {
  AssignmentBurndownView,
  AssignmentDashboardView,
  AssignmentLeaderboardView,
  AssignmentOwnershipView,
  DesignProposalView,
  OriginalityReportView,
  ProjectAssignment,
  ProjectCheckpointWithSubmissions,
  ProjectTeam,
} from "@/lib/workspace/cohort-types";

const BASE = "/api/workspace-cohorts";

export async function getCohorts(batchId?: string): Promise<ProjectAssignment[]> {
  const qs = batchId ? `?batch_id=${encodeURIComponent(batchId)}` : "";
  return apiGet<ProjectAssignment[]>(`${BASE}${qs}`);
}

export async function getCohort(cohortId: string): Promise<ProjectAssignment> {
  return apiGet<ProjectAssignment>(`${BASE}/${cohortId}`);
}

export async function getCohortTeams(cohortId: string): Promise<ProjectTeam[]> {
  return apiGet<ProjectTeam[]>(`${BASE}/${cohortId}/teams`);
}

// Each team row embeds its member roster and activity feed.
export async function getCohortDashboard(cohortId: string): Promise<AssignmentDashboardView> {
  return apiGet<AssignmentDashboardView>(`${BASE}/${cohortId}/dashboard`);
}

export async function getCohortBurndown(cohortId: string): Promise<AssignmentBurndownView> {
  return apiGet<AssignmentBurndownView>(`${BASE}/${cohortId}/burndown`);
}

export async function getCohortOwnership(cohortId: string): Promise<AssignmentOwnershipView> {
  return apiGet<AssignmentOwnershipView>(`${BASE}/${cohortId}/ownership`);
}

export async function getCohortLeaderboard(cohortId: string): Promise<AssignmentLeaderboardView> {
  return apiGet<AssignmentLeaderboardView>(`${BASE}/${cohortId}/leaderboard`);
}

// Each checkpoint row embeds every team's submission against it.
export async function getCohortCheckpoints(cohortId: string): Promise<ProjectCheckpointWithSubmissions[]> {
  return apiGet<ProjectCheckpointWithSubmissions[]>(`${BASE}/${cohortId}/checkpoints`);
}

export async function getCohortOriginalityReports(cohortId: string): Promise<OriginalityReportView[]> {
  return apiGet<OriginalityReportView[]>(`${BASE}/${cohortId}/originality`);
}

// Staff-only — every team's proposals against one checkpoint.
export async function listAllDesignProposals(checkpointId: string): Promise<DesignProposalView[]> {
  return apiGet<DesignProposalView[]>(`${BASE}/checkpoints/${checkpointId}/proposals`);
}
