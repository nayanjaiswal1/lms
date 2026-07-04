import "server-only";

import { apiGet, apiAction } from "@/lib/server/api";
import type { Job, JobRun, OrgJobStats } from "@/lib/jobs/types";

export interface JobsFilter {
  status?: string;
  handler?: string;
  after?: string;
  limit?: number;
}

export interface JobListPage {
  jobs: Job[];
  next_cursor: string;
}

export interface JobDetail {
  job: Job;
  runs: JobRun[];
}

export async function fetchOrgJobs(
  orgID: string,
  filter: JobsFilter,
): Promise<JobListPage> {
  const params = new URLSearchParams();
  if (filter.status) params.set("status", filter.status);
  if (filter.handler) params.set("handler", filter.handler);
  if (filter.after) params.set("after", filter.after);
  if (filter.limit !== undefined) params.set("limit", String(filter.limit));
  const qs = params.toString();
  return apiGet<JobListPage>(`/api/orgs/${orgID}/jobs${qs ? `?${qs}` : ""}`);
}

export async function fetchJob(
  orgID: string,
  jobID: string,
): Promise<JobDetail> {
  return apiGet<JobDetail>(`/api/orgs/${orgID}/jobs/${jobID}`);
}

export async function fetchOrgJobStats(orgID: string): Promise<OrgJobStats> {
  return apiGet<OrgJobStats>(`/api/orgs/${orgID}/jobs/stats`);
}

export async function cancelJob(orgID: string, jobID: string): Promise<void> {
  const result = await apiAction("POST", `/api/orgs/${orgID}/jobs/${jobID}/cancel`);
  if (!result.ok) throw new Error(result.error ?? "Failed to cancel job.");
}

export async function retryJob(orgID: string, jobID: string): Promise<void> {
  const result = await apiAction("POST", `/api/orgs/${orgID}/jobs/${jobID}/retry`);
  if (!result.ok) throw new Error(result.error ?? "Failed to retry job.");
}

export async function pauseJob(
  orgID: string,
  jobID: string,
  paused: boolean,
): Promise<void> {
  const result = await apiAction(
    "POST",
    `/api/orgs/${orgID}/jobs/${jobID}/${paused ? "pause" : "resume"}`,
  );
  if (!result.ok) throw new Error(result.error ?? "Failed to update job.");
}
