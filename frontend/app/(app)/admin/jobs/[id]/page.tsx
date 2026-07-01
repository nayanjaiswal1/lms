import Link from "next/link";
import { notFound } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { fetchAdminJobDetail } from "@/lib/server/admin-jobs";
import {
  forceRetryJobAction,
  cancelJobAction,
} from "@/app/(app)/admin/jobs/actions";
import ROUTES from "@/lib/routes";
import type { JobStatus, JobRun } from "@/lib/jobs/types";

const STATUS_VARIANT: Record<
  JobStatus,
  "default" | "secondary" | "destructive" | "outline"
> = {
  pending:   "outline",
  queued:    "secondary",
  running:   "default",
  success:   "secondary",
  failed:    "destructive",
  dead:      "destructive",
  cancelled: "outline",
};

const PRIORITY_LABEL: Record<number, string> = {
  1: "Critical",
  2: "High",
  3: "Normal",
  4: "Low",
  5: "Background",
};

function fmtDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleString(undefined, {
    year: "numeric", month: "short", day: "numeric",
    hour: "2-digit", minute: "2-digit", second: "2-digit",
  });
}

function fmtDuration(ms: number | null | undefined): string {
  if (ms === null || ms === undefined) return "—";
  if (ms < 1000) return `${ms}ms`;
  if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`;
  return `${Math.floor(ms / 60000)}m ${Math.floor((ms % 60000) / 1000)}s`;
}

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function AdminJobDetailPage({ params }: PageProps) {
  const [myPerms, { id: jobID }] = await Promise.all([
    getMyPermissions(),
    params,
  ]);
  if (!myPerms.includes(PERMISSIONS.ADMIN.VIEW_JOBS)) notFound();

  const detail = await fetchAdminJobDetail(jobID).catch(() => null);
  if (!detail) notFound();
  const { job, runs } = detail;
  const canManage = myPerms.includes(PERMISSIONS.ADMIN.MANAGE_JOBS);
  const canRetry = job.status === "failed" || job.status === "dead";
  const canCancel = job.status === "pending" || job.status === "queued";

  return (
    <div className="page-container py-8">
      <div className="page-header">
        <div>
          <div className="flex items-center gap-3 flex-wrap">
            <h1 className="page-title font-mono text-xl">{job.handler}</h1>
            <Badge variant={STATUS_VARIANT[job.status]}>{job.status}</Badge>
            {job.job_type === "cron" && (
              <Badge variant="outline">cron</Badge>
            )}
          </div>
          <p className="text-muted-foreground mt-1 font-mono text-xs">{job.id}</p>
        </div>
        <div className="flex items-center gap-2">
          {canManage && canRetry && (
            <form action={forceRetryJobAction.bind(null, job.id)}>
              <Button type="submit" variant="outline" size="sm">Force Retry</Button>
            </form>
          )}
          {canManage && canCancel && (
            <form action={cancelJobAction.bind(null, job.id)}>
              <Button type="submit" variant="outline" size="sm" className="text-destructive border-destructive/30 hover:bg-destructive/10">
                Cancel
              </Button>
            </form>
          )}
          <Button asChild variant="outline" size="sm">
            <Link href={ROUTES.ADMIN_JOBS}>Back to Jobs</Link>
          </Button>
        </div>
      </div>

      <div className="mt-8 grid gap-6 md:grid-cols-2">
        {/* Identity */}
        <div className="card-base p-6 space-y-3">
          <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide">Identity</h2>
          <InfoRow label="Priority" value={`${PRIORITY_LABEL[job.priority] ?? job.priority} (${job.priority})`} />
          <InfoRow label="Type" value={job.job_type} />
          <InfoRow label="Org" value={job.org_id ?? "—"} mono />
          <InfoRow label="Created by" value={job.created_by ?? "—"} mono />
          <InfoRow label="Worker" value={job.worker_id ?? "—"} mono />
          <InfoRow label="Idempotency key" value={job.idempotency_key ?? "—"} mono />
        </div>

        {/* Timing */}
        <div className="card-base p-6 space-y-3">
          <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide">Timing</h2>
          <InfoRow label="Run at" value={fmtDate(job.run_at)} />
          <InfoRow label="Last run" value={fmtDate(job.last_run_at)} />
          <InfoRow label="Next run" value={fmtDate(job.next_run_at)} />
          <InfoRow label="Last duration" value={fmtDuration(job.last_duration_ms)} />
          {job.schedule && <InfoRow label="Schedule" value={job.schedule} mono />}
          <InfoRow label="Claimed at" value={fmtDate(job.claimed_at)} />
          <InfoRow label="Created at" value={fmtDate(job.created_at)} />
        </div>

        {/* Retry config */}
        <div className="card-base p-6 space-y-3">
          <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide">Retry Config</h2>
          <InfoRow label="Max retries" value={String(job.max_retries)} />
          <InfoRow label="Retry count" value={String(job.retry_count)} />
          <InfoRow label="Timeout" value={fmtDuration(job.timeout_ms)} />
        </div>

        {/* Error (if any) */}
        {job.last_error && (
          <div className="card-base p-6 border-destructive/30">
            <h2 className="text-sm font-semibold text-destructive uppercase tracking-wide mb-3">Last Error</h2>
            <pre className="text-xs text-destructive whitespace-pre-wrap break-all font-mono leading-relaxed">
              {job.last_error}
            </pre>
          </div>
        )}
      </div>

      {/* Payload */}
      <div className="card-base p-6 mt-6">
        <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide mb-3">Payload</h2>
        <pre className="text-xs font-mono text-foreground whitespace-pre-wrap break-all leading-relaxed max-h-60 overflow-y-auto">
          {JSON.stringify(job.payload, null, 2)}
        </pre>
      </div>

      {/* Run history */}
      <section className="mt-8">
        <h2 className="section-title mb-4">Run History</h2>
        <RunsTable runs={runs} />
      </section>
    </div>
  );
}

function InfoRow({ label, value, mono = false }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="flex items-start justify-between gap-4">
      <span className="text-sm text-muted-foreground shrink-0">{label}</span>
      <span className={`text-sm text-right break-all ${mono ? "font-mono" : ""}`}>{value}</span>
    </div>
  );
}

function RunsTable({ runs }: { runs: JobRun[] }) {
  if (runs.length === 0) {
    return (
      <div className="empty-state">
        <p className="text-muted-foreground">No run history yet.</p>
      </div>
    );
  }

  function fmtShort(iso: string | null | undefined): string {
    if (!iso) return "—";
    return new Date(iso).toLocaleString(undefined, {
      month: "short", day: "numeric", hour: "2-digit", minute: "2-digit", second: "2-digit",
    });
  }

  function fmtMs(ms: number | null | undefined): string {
    if (ms === null || ms === undefined) return "—";
    if (ms < 1000) return `${ms}ms`;
    return `${(ms / 1000).toFixed(1)}s`;
  }

  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-muted-foreground">
            <th className="pb-2 pr-4 font-medium">#</th>
            <th className="pb-2 pr-4 font-medium">Status</th>
            <th className="pb-2 pr-4 font-medium">Worker</th>
            <th className="pb-2 pr-4 font-medium">Started</th>
            <th className="pb-2 pr-4 font-medium">Finished</th>
            <th className="pb-2 pr-4 font-medium">Duration</th>
            <th className="pb-2 font-medium">Error</th>
          </tr>
        </thead>
        <tbody>
          {runs.map((run) => (
            <tr key={run.id} className="border-b border-border last:border-0">
              <td className="py-3 pr-4 text-muted-foreground">{run.attempt}</td>
              <td className="py-3 pr-4">
                <Badge
                  variant={
                    run.status === "success"
                      ? "secondary"
                      : run.status === "running"
                      ? "default"
                      : "destructive"
                  }
                >
                  {run.status}
                </Badge>
              </td>
              <td className="py-3 pr-4 font-mono text-xs text-muted-foreground">
                {run.worker_id.slice(0, 12)}…
              </td>
              <td className="py-3 pr-4 text-muted-foreground">{fmtShort(run.started_at)}</td>
              <td className="py-3 pr-4 text-muted-foreground">{fmtShort(run.finished_at)}</td>
              <td className="py-3 pr-4 text-muted-foreground">{fmtMs(run.duration_ms)}</td>
              <td className="py-3 max-w-xs">
                {run.error ? (
                  <span className="text-destructive text-xs font-mono truncate block" title={run.error}>
                    {run.error.slice(0, 80)}{run.error.length > 80 ? "…" : ""}
                  </span>
                ) : (
                  <span className="text-muted-foreground">—</span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
