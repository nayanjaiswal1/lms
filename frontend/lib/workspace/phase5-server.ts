import "server-only";

import { apiGet } from "@/lib/server/api";
import type { FeedbackView, MemberReport, Release, ReleaseNotes, Sprint } from "@/lib/workspace/types";

export async function listWorkspaceReleases(workspaceId: string): Promise<Release[]> {
  return apiGet<Release[]>(`/api/workspaces/${workspaceId}/releases`);
}

export async function getReleaseNotes(workspaceId: string, releaseId: string, polish: boolean): Promise<ReleaseNotes> {
  const qs = polish ? "?polish=true" : "";
  return apiGet<ReleaseNotes>(`/api/workspaces/${workspaceId}/releases/${releaseId}/notes${qs}`);
}

export async function listWorkspaceSprints(workspaceId: string): Promise<Sprint[]> {
  return apiGet<Sprint[]>(`/api/workspaces/${workspaceId}/sprints`);
}

export async function getWorkspaceFeedback(workspaceId: string): Promise<FeedbackView> {
  return apiGet<FeedbackView>(`/api/workspaces/${workspaceId}/feedback`);
}

export async function getMemberReport(workspaceId: string, userId: string): Promise<MemberReport> {
  return apiGet<MemberReport>(`/api/workspaces/${workspaceId}/members/${userId}/report`);
}
