import "server-only";

import { apiGet } from "@/lib/server/api";
import type { Dashboard, DashboardFilter, GitlabLink, Page, TimeLog } from "@/lib/workspace/types";

export async function getItemGitlabLinks(workspaceId: string, itemId: string): Promise<GitlabLink[]> {
  return apiGet<GitlabLink[]>(`/api/workspaces/${workspaceId}/items/${itemId}/gitlab`);
}

export async function listTimeLogs(
  workspaceId: string,
  filters: { item?: string; user?: string; cursor?: string; limit?: number } = {},
): Promise<Page<TimeLog>> {
  const params = new URLSearchParams();
  if (filters.item) params.set("item", filters.item);
  if (filters.user) params.set("user", filters.user);
  if (filters.cursor) params.set("cursor", filters.cursor);
  if (filters.limit) params.set("limit", String(filters.limit));
  const qs = params.toString();
  return apiGet<Page<TimeLog>>(`/api/workspaces/${workspaceId}/time-logs${qs ? `?${qs}` : ""}`);
}

export async function getWorkspaceDashboard(workspaceId: string, filter: DashboardFilter = {}): Promise<Dashboard> {
  const params = new URLSearchParams();
  if (filter.from) params.set("from", filter.from);
  if (filter.to) params.set("to", filter.to);
  if (filter.track) params.set("track", filter.track);
  if (filter.user) params.set("user", filter.user);
  const qs = params.toString();
  return apiGet<Dashboard>(`/api/workspaces/${workspaceId}/dashboard${qs ? `?${qs}` : ""}`);
}
