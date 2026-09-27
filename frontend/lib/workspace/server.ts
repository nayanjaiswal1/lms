import "server-only";

import { apiGet, apiGetPublic } from "@/lib/server/api";
import type {
  Interest,
  InterestStatus,
  Member,
  OnboardingStep,
  Page,
  ProjectDetail,
  ProjectSummary,
  PublicProject,
  RequirementView,
  Track,
} from "@/lib/workspace/types";

// Every list route returns `{"data": {...Page}}` (cursor pagination) except
// the ones the contract marks "array directly under data" (members, tracks,
// onboarding, invitations) — mirrors the same split already used in
// lib/projects/server.ts.

export async function listWorkspaces(cursor?: string, limit?: number): Promise<Page<ProjectSummary>> {
  const params = new URLSearchParams();
  if (cursor) params.set("cursor", cursor);
  if (limit) params.set("limit", String(limit));
  const qs = params.toString();
  return apiGet<Page<ProjectSummary>>(`/api/workspaces${qs ? `?${qs}` : ""}`);
}

export async function listMyWorkspaceInvitations(): Promise<ProjectSummary[]> {
  return apiGet<ProjectSummary[]>(`/api/workspaces/invitations`);
}

export async function getWorkspace(workspaceId: string): Promise<ProjectDetail> {
  return apiGet<ProjectDetail>(`/api/workspaces/${workspaceId}`);
}

export async function getWorkspaceRequirement(workspaceId: string): Promise<RequirementView> {
  return apiGet<RequirementView>(`/api/workspaces/${workspaceId}/requirement`);
}

export async function listWorkspaceInterests(
  workspaceId: string,
  status?: InterestStatus,
  cursor?: string,
  limit?: number,
): Promise<Page<Interest>> {
  const params = new URLSearchParams();
  if (status) params.set("status", status);
  if (cursor) params.set("cursor", cursor);
  if (limit) params.set("limit", String(limit));
  const qs = params.toString();
  return apiGet<Page<Interest>>(`/api/workspaces/${workspaceId}/interests${qs ? `?${qs}` : ""}`);
}

export async function listWorkspaceMembers(workspaceId: string): Promise<Member[]> {
  return apiGet<Member[]>(`/api/workspaces/${workspaceId}/members`);
}

export async function listWorkspaceTracks(workspaceId: string): Promise<Track[]> {
  return apiGet<Track[]>(`/api/workspaces/${workspaceId}/tracks`);
}

export async function listWorkspaceOnboarding(workspaceId: string): Promise<OnboardingStep[]> {
  return apiGet<OnboardingStep[]>(`/api/workspaces/${workspaceId}/onboarding`);
}

// ── Public share page ───────────────────────────────────────────────────────
// revalidate: 0 opts this fetch out of the Next Data Cache entirely (matches
// the backend's own `Cache-Control: no-store` on this route — seats-left and
// deadline must never be served stale, and the response must never be shared
// across visitors/tokens).
export async function getPublicWorkspace(shareToken: string): Promise<PublicProject> {
  return apiGetPublic<PublicProject>(`/api/public/workspaces/${shareToken}`, { revalidate: 0 });
}
