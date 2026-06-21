import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { fetchOrgJobs, fetchOrgJobStats } from "@/lib/server/jobs";
import type { Job, JobStatus, JobPriority } from "@/lib/jobs/types";
import { cancelJobAction, retryJobAction } from "@/app/org/settings/jobs/[id]/actions";
import ROUTES from "@/lib/routes";
import { cn } from "@/lib/utils";

export const metadata: Metadata = {
  title: "Jobs — Organisation Settings",
};

async function getCurrentOrgId(): Promise<string | null> {
  const store = await cookies();
  const token = store.get("access_token")?.value;
  if (!token) return null;
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = JSON.parse(
      Buffer.from(parts[1], "base64url").toString(),
    ) as { org_id?: string };
    return payload.org_id ?? null;
  } catch {
    return null;
  }
}

const STATUS_TABS = [
  { label: "All",       value: undefined },
  { label: "Running",   value: "running" },
  { label: "Failed",    value: "failed" },
  { label: "Dead",      value: "dead" },
  { label: "Completed", value: "success" },
] as const;

function statusBadgeClass(status: JobStatus): string {
  switch (status) {
    case "running":   return "bg-primary/10 text-primary";
    case "failed":
    case "dead":      return "bg-destructive/10 text-destructive";
    case "success":   return "bg-success/10 text-success";
    case "cancelled": return "bg-muted text-muted-foreground line-through";
    default:          return "bg-muted text-muted-foreground";
  }
}

function priorityBadgeClass(priority: JobPriority): string {
  switch (priority) {
    case 1: return "bg-destructive/20 text-destructive";
    case 2: return "bg-warning/10 text-warning";
    case 3: return "bg-muted text-muted-foreground";
    case 4: return "bg-muted/50 text-muted-foreground";
    case 5: return "bg-muted/30 text-muted-foreground";
  }
}

const PRIORITY_LABELS: Record<JobPriority, string> = {
  1: "Critical",
  2: "High",
  3: "Normal",
  4: "Low",
  5: "Background",
};

function formatRelativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const seconds = Math.floor(diff / 1000);
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

function formatDuration(ms: number | null): string {
  if (ms === null) return "—";
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
}

function JobRow({ job, orgId }: { job: Job; orgId: string }) {
  const canCancel = job.status === "pending" || job.status === "queued";
  const canRetry = job.status === "failed" || job.status === "dead";

  return (
    <tr className="border-b border-border last:border-0 hover:bg-muted/40 transition-colors duration-[--duration-fast]">
      <td className="py-3 px-4">
        <Link
          href={`/org/settings/jobs/${job.id}`}
          className="font-mono text-sm text-foreground hover:text-primary transition-colors duration-[--duration-fast] break-all"
        >
          {job.handler}
        </Link>
        {job.job_type === "cron" && job.schedule && (
          <p className="text-xs text-muted-foreground mt-0.5">{job.schedule}</p>
        )}
      </td>
      <td className="py-3 px-4">
        <span
          className={cn(
            "inline-flex items-center px-2 py-0.5 rounded-[--radius-sm] text-xs font-medium",
            statusBadgeClass(job.status),
          )}
        >
          {job.status}
        </span>
      </td>
      <td className="py-3 px-4">
        <span
          className={cn(
            "inline-flex items-center px-2 py-0.5 rounded-[--radius-sm] text-xs font-medium",
            priorityBadgeClass(job.priority),
          )}
        >
          {PRIORITY_LABELS[job.priority]}
        </span>
      </td>
      <td className="py-3 px-4 text-sm text-muted-foreground whitespace-nowrap">
        {formatRelativeTime(job.created_at)}
      </td>
      <td className="py-3 px-4 text-sm text-muted-foreground whitespace-nowrap">
        {formatDuration(job.last_duration_ms)}
      </td>
      <td className="py-3 px-4">
        <div className="flex items-center gap-2">
          {canCancel && (
            <form action={cancelJobAction.bind(null, orgId, job.id)}>
              <Button size="sm" variant="outline" type="submit" aria-label={`Cancel job ${job.handler}`}>
                Cancel
              </Button>
            </form>
          )}
          {canRetry && (
            <form action={retryJobAction.bind(null, orgId, job.id)}>
              <Button size="sm" variant="outline" type="submit" aria-label={`Retry job ${job.handler}`}>
                Retry
              </Button>
            </form>
          )}
          {!canCancel && !canRetry && (
            <span className="text-xs text-muted-foreground">—</span>
          )}
        </div>
      </td>
    </tr>
  );
}

export default async function JobsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; handler?: string; after?: string }>;
}) {
  const orgId = await getCurrentOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const { status, handler, after } = await searchParams;

  const [jobsPage, stats] = await Promise.all([
    fetchOrgJobs(orgId, { status, handler, after, limit: 50 }),
    fetchOrgJobStats(orgId).catch(() => null),
  ]);

  const { jobs, next_cursor } = jobsPage;

  const handlerParam = handler ? `&handler=${encodeURIComponent(handler)}` : "";

  return (
    <div className="space-y-6">
      {/* Stats quota bar */}
      {stats && (
        <div className="card-base p-4 flex flex-wrap items-center gap-4 text-sm">
          <span className="text-muted-foreground">
            Running:{" "}
            <span className="font-semibold text-foreground">{stats.running}</span>
            <span className="text-muted-foreground"> / {stats.quota.max_concurrent} max</span>
          </span>
          <span className="text-muted-foreground">
            Queued:{" "}
            <span className="font-semibold text-foreground">{stats.queued}</span>
            <span className="text-muted-foreground"> / {stats.quota.max_queued} max</span>
          </span>
          <span className="text-muted-foreground">
            Failed: <span className="font-semibold text-destructive">{stats.failed}</span>
          </span>
          <span className="text-muted-foreground">
            Dead: <span className="font-semibold text-destructive">{stats.dead}</span>
          </span>
          <div className="ml-auto w-full sm:w-48">
            <div className="progress-track">
              <div
                className="progress-fill"
                style={{ "--progress": `${Math.min(100, (stats.running / stats.quota.max_concurrent) * 100)}%` } as React.CSSProperties}
              />
            </div>
          </div>
        </div>
      )}

      <div className="card-base p-6">
        {/* Header */}
        <div className="page-header mb-4">
          <div>
            <h2 className="text-lg font-semibold text-foreground">Background Jobs</h2>
            <p className="text-sm text-muted-foreground">
              Monitor and manage scheduled and one-time background tasks for your organisation.
            </p>
          </div>
          {handler && (
            <Badge variant="secondary">
              Handler: {handler}
            </Badge>
          )}
        </div>

        {/* Status filter tabs */}
        <div
          role="tablist"
          aria-label="Filter jobs by status"
          className="flex gap-2 overflow-x-auto pb-2 mb-6"
        >
          {STATUS_TABS.map((tab) => {
            const isActive = status === tab.value || (tab.value === undefined && !status);
            const href = tab.value
              ? `?status=${tab.value}${handlerParam}`
              : `?${handlerParam.slice(1)}`;
            return (
              <Link
                key={tab.label}
                href={href}
                role="tab"
                aria-selected={isActive}
                className={cn(
                  "flex-shrink-0 px-4 py-2 rounded-full text-sm font-medium transition-colors duration-[--duration-fast]",
                  isActive
                    ? "bg-primary text-primary-foreground"
                    : "bg-muted text-muted-foreground hover:text-foreground",
                )}
              >
                {tab.label}
              </Link>
            );
          })}
        </div>

        {/* Jobs table */}
        {jobs.length === 0 ? (
          <div className="empty-state py-12">
            <p className="text-sm text-muted-foreground">No jobs found for the selected filter.</p>
          </div>
        ) : (
          <>
            <div className="table-responsive">
              <table className="w-full text-left">
                <thead>
                  <tr className="border-b border-border">
                    <th className="pb-3 px-4 text-xs font-semibold text-muted-foreground uppercase tracking-wider">Handler</th>
                    <th className="pb-3 px-4 text-xs font-semibold text-muted-foreground uppercase tracking-wider">Status</th>
                    <th className="pb-3 px-4 text-xs font-semibold text-muted-foreground uppercase tracking-wider">Priority</th>
                    <th className="pb-3 px-4 text-xs font-semibold text-muted-foreground uppercase tracking-wider">Created</th>
                    <th className="pb-3 px-4 text-xs font-semibold text-muted-foreground uppercase tracking-wider">Duration</th>
                    <th className="pb-3 px-4 text-xs font-semibold text-muted-foreground uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {jobs.map((job) => (
                    <JobRow key={job.id} job={job} orgId={orgId} />
                  ))}
                </tbody>
              </table>
            </div>

            {next_cursor && (
              <div className="pt-4 flex justify-center">
                <Button asChild variant="secondary">
                  <Link
                    href={`?${status ? `status=${status}&` : ""}${handlerParam ? `${handlerParam.slice(1)}&` : ""}after=${encodeURIComponent(next_cursor)}`}
                  >
                    Next page
                  </Link>
                </Button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
