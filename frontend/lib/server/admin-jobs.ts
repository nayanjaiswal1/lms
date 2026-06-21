import "server-only";

import { apiGet, apiAction } from "@/lib/server/api";
import type { Job, OrgJobStats, WorkerInfo } from "@/lib/jobs/types";

export interface AdminJobsFilter {
  org_id?: string;
  status?: string;
  handler?: string;
  after?: string;
  limit?: number;
}

export interface AdminJobListPage {
  jobs: Job[];
  next_cursor: string;
}

export interface WorkerHealthResponse {
  workers: WorkerInfo[];
  leader: string;
}

export interface PlatformStatsResponse {
  per_org: OrgJobStats[];
}

export interface OrgQuota {
  max_concurrent: number;
  max_queued: number;
  priority_floor: number;
}

export interface PauseOrgResult {
  cancelled: number;
}

export async function fetchAdminJobs(
  filter: AdminJobsFilter,
): Promise<AdminJobListPage> {
  const params = new URLSearchParams();
  if (filter.org_id) params.set("org_id", filter.org_id);
  if (filter.status) params.set("status", filter.status);
  if (filter.handler) params.set("handler", filter.handler);
  if (filter.after) params.set("after", filter.after);
  if (filter.limit !== undefined) params.set("limit", String(filter.limit));
  const qs = params.toString();
  return apiGet<AdminJobListPage>(`/api/admin/jobs${qs ? `?${qs}` : ""}`);
}

export async function fetchWorkerHealth(): Promise<WorkerHealthResponse> {
  return apiGet<WorkerHealthResponse>("/api/admin/jobs/workers");
}

export async function fetchPlatformStats(): Promise<PlatformStatsResponse> {
  return apiGet<PlatformStatsResponse>("/api/admin/jobs/stats");
}

export async function updateOrgQuota(
  orgID: string,
  quota: OrgQuota,
): Promise<void> {
  const result = await apiAction(
    "PATCH",
    `/api/admin/orgs/${orgID}/jobs/quota`,
    quota,
  );
  if (!result.ok) throw new Error(result.error ?? "Failed to update quota.");
}

export async function pauseAllOrgJobs(
  orgID: string,
): Promise<PauseOrgResult> {
  const result = await apiAction<PauseOrgResult>(
    "POST",
    `/api/admin/orgs/${orgID}/jobs/pause`,
  );
  if (!result.ok) throw new Error(result.error ?? "Failed to pause org jobs.");
  return result.data ?? { cancelled: 0 };
}

export async function forceRetryJob(jobID: string): Promise<void> {
  const result = await apiAction(
    "POST",
    `/api/admin/jobs/${jobID}/retry`,
  );
  if (!result.ok) throw new Error(result.error ?? "Failed to retry job.");
}
