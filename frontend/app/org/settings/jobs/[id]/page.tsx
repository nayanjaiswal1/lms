import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect, notFound } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { fetchJob } from "@/lib/server/jobs";
import type { JobStatus, JobPriority } from "@/lib/jobs/types";
import { cancelJobAction, retryJobAction, pauseJobAction } from "@/app/org/settings/jobs/[id]/actions";
import ROUTES from "@/lib/routes";
import { cn } from "@/lib/utils";

export const metadata: Metadata = { title: "Job Detail — Organisation Settings" };

async function getCurrentOrgId(): Promise<string | null> {
  const store = await cookies();
  const token = store.get("access_token")?.value;
  if (!token) return null;
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString()) as { org_id?: string };
    return payload.org_id ?? null;
  } catch { return null; }
}

function statusClass(s: JobStatus | string): string {
  if (s === "running") return "bg-primary/10 text-primary";
  if (s === "failed" || s === "dead") return "bg-destructive/10 text-destructive";
  if (s === "success") return "bg-success/10 text-success";
  if (s === "cancelled") return "bg-muted text-muted-foreground line-through";
  return "bg-muted text-muted-foreground";
}

function priorityClass(p: JobPriority): string {
  if (p === 1) return "bg-destructive/20 text-destructive";
  if (p === 2) return "bg-warning/10 text-warning";
  if (p === 4) return "bg-muted/50 text-muted-foreground";
  if (p === 5) return "bg-muted/30 text-muted-foreground";
  return "bg-muted text-muted-foreground";
}

const PRIORITY_LABELS: Record<JobPriority, string> = { 1: "Critical", 2: "High", 3: "Normal", 4: "Low", 5: "Background" };

function fmt(ms: number | null): string {
  if (ms === null) return "—";
  return ms < 1000 ? `${ms}ms` : `${(ms / 1000).toFixed(1)}s`;
}

function fmtDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleString("en-US", { month: "short", day: "numeric", year: "numeric", hour: "2-digit", minute: "2-digit" });
}

export default async function JobDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const orgId = await getCurrentOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const { id: jobId } = await params;
  let detail: Awaited<ReturnType<typeof fetchJob>>;
  try { detail = await fetchJob(orgId, jobId); } catch { notFound(); }

  const { job, runs } = detail;
  const canCancel = job.status === "pending" || job.status === "queued";
  const canRetry = job.status === "failed" || job.status === "dead";
  const isCron = job.job_type === "cron";
  const payloadPreview = JSON.stringify(job.payload);

  return (
    <div className="space-y-6">
      <Link href="/org/settings/jobs" className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground transition-colors duration-[--duration-fast]">
        ← Back to Jobs
      </Link>

      {/* Job metadata */}
      <div className="card-base p-6 space-y-5">
        <div className="page-header mb-0">
          <div>
            <h2 className="text-lg font-semibold text-foreground font-mono break-all">{job.handler}</h2>
            <p className="text-xs text-muted-foreground mt-1">ID: <span className="font-mono">{job.id}</span></p>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            {canCancel && (
              <form action={cancelJobAction.bind(null, orgId, job.id)}>
                <Button type="submit" variant="outline" size="sm">Cancel Job</Button>
              </form>
            )}
            {canRetry && (
              <form action={retryJobAction.bind(null, orgId, job.id)}>
                <Button type="submit" variant="outline" size="sm">Retry Job</Button>
              </form>
            )}
            {isCron && (
              <form action={pauseJobAction.bind(null, orgId, job.id, job.status !== "cancelled")}>
                <Button type="submit" variant="outline" size="sm">
                  {job.status === "cancelled" ? "Resume Schedule" : "Pause Schedule"}
                </Button>
              </form>
            )}
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <span className={cn("inline-flex items-center px-2.5 py-1 rounded-[--radius-sm] text-xs font-semibold", statusClass(job.status))}>{job.status}</span>
          <span className={cn("inline-flex items-center px-2.5 py-1 rounded-[--radius-sm] text-xs font-semibold", priorityClass(job.priority))}>{PRIORITY_LABELS[job.priority]}</span>
          <span className="text-xs bg-muted text-muted-foreground px-2.5 py-1 rounded-[--radius-sm] font-medium">{isCron ? "Cron" : "One-time"}</span>
        </div>

        <dl className="grid-responsive-2 gap-4 text-sm">
          <div><dt className="text-muted-foreground mb-0.5">Retries</dt><dd className="text-foreground font-medium">{job.retry_count} / {job.max_retries}</dd></div>
          <div><dt className="text-muted-foreground mb-0.5">Timeout</dt><dd className="text-foreground font-medium">{fmt(job.timeout_ms)}</dd></div>
          <div><dt className="text-muted-foreground mb-0.5">Scheduled at</dt><dd className="text-foreground font-medium">{fmtDate(job.run_at)}</dd></div>
          {job.last_run_at && <div><dt className="text-muted-foreground mb-0.5">Last run</dt><dd className="text-foreground font-medium">{fmtDate(job.last_run_at)}</dd></div>}
          {isCron && job.schedule && <div><dt className="text-muted-foreground mb-0.5">Schedule</dt><dd className="font-mono text-foreground">{job.schedule}</dd></div>}
          {isCron && job.next_run_at && <div><dt className="text-muted-foreground mb-0.5">Next run</dt><dd className="text-foreground font-medium">{fmtDate(job.next_run_at)}</dd></div>}
        </dl>

        <div>
          <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wider mb-2">Payload</p>
          <pre className="bg-muted rounded-[--radius-md] p-3 text-xs font-mono text-foreground overflow-x-auto whitespace-pre-wrap break-all">
            {payloadPreview.length > 200 ? `${payloadPreview.slice(0, 200)}…` : payloadPreview}
          </pre>
        </div>

        {job.last_error && (
          <div>
            <p className="text-xs font-semibold text-destructive uppercase tracking-wider mb-2">Last Error</p>
            <pre className="bg-destructive/5 border border-destructive/20 rounded-[--radius-md] p-3 text-xs font-mono text-destructive overflow-x-auto whitespace-pre-wrap break-all">
              {job.last_error}
            </pre>
          </div>
        )}
      </div>

      {/* Run history */}
      <div className="card-base p-6">
        <h3 className="text-base font-semibold text-foreground mb-4">
          Run History
          {runs.length > 0 && <span className="ml-2 text-sm font-normal text-muted-foreground">({runs.length} {runs.length === 1 ? "attempt" : "attempts"})</span>}
        </h3>

        {runs.length === 0 ? (
          <div className="empty-state py-8"><p className="text-sm text-muted-foreground">No runs recorded yet.</p></div>
        ) : (
          <div className="table-responsive">
            <table className="w-full text-left">
              <thead>
                <tr className="border-b border-border">
                  {["Attempt", "Status", "Duration", "Error", "Started"].map((h) => (
                    <th key={h} className="pb-3 px-4 text-xs font-semibold text-muted-foreground uppercase tracking-wider">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {runs.map((run) => (
                  <tr key={run.id} className="border-b border-border last:border-0">
                    <td className="py-3 px-4 text-sm text-foreground">#{run.attempt}</td>
                    <td className="py-3 px-4">
                      <span className={cn("inline-flex items-center px-2 py-0.5 rounded-[--radius-sm] text-xs font-medium", statusClass(run.status))}>
                        {run.status}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-sm text-muted-foreground whitespace-nowrap">{fmt(run.duration_ms)}</td>
                    <td className="py-3 px-4 text-sm text-muted-foreground">
                      {run.error
                        ? <span className="text-destructive break-all">{run.error.slice(0, 80)}{run.error.length > 80 ? "…" : ""}</span>
                        : "—"}
                    </td>
                    <td className="py-3 px-4 text-sm text-muted-foreground whitespace-nowrap">{fmtDate(run.started_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
