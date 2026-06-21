export type JobStatus =
  | "pending"
  | "queued"
  | "running"
  | "success"
  | "failed"
  | "dead"
  | "cancelled";

export type JobPriority = 1 | 2 | 3 | 4 | 5;

export type JobType = "one_time" | "cron";

export interface Job {
  id: string;
  handler: string;
  status: JobStatus;
  priority: JobPriority;
  payload: Record<string, unknown>;
  job_type: JobType;
  schedule: string | null;
  run_at: string;
  next_run_at: string | null;
  last_run_at: string | null;
  last_duration_ms: number | null;
  last_error: string | null;
  max_retries: number;
  retry_count: number;
  timeout_ms: number;
  idempotency_key: string | null;
  org_id: string | null;
  created_by: string | null;
  worker_id: string | null;
  claimed_at: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface JobRun {
  id: string;
  job_id: string;
  status: string;
  attempt: number;
  worker_id: string;
  started_at: string | null;
  finished_at: string | null;
  duration_ms: number | null;
  error: string | null;
  heartbeat_at: string | null;
  created_at: string;
}

export interface OrgJobStats {
  org_id: string;
  org_name: string;
  running: number;
  queued: number;
  failed: number;
  dead: number;
  quota: {
    max_concurrent: number;
    max_queued: number;
    priority_floor: number;
  };
}

export interface WorkerInfo {
  instance_id: string;
  slots_busy: number;
  slots_total: number;
  last_seen: string;
}
