import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import {
  forceRetryJobAction,
  cancelJobAction,
} from "@/app/(app)/admin/jobs/actions";
import ROUTES from "@/lib/routes";
import type { Job, JobStatus } from "@/lib/jobs/types";

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

const ALL_STATUSES: JobStatus[] = [
  "pending", "queued", "running", "success", "failed", "dead", "cancelled",
];

function fmt(iso: string): string {
  return new Date(iso).toLocaleString(undefined, {
    month:  "short",
    day:    "numeric",
    hour:   "2-digit",
    minute: "2-digit",
  });
}

interface FilterParams {
  org_id?: string;
  status?: string;
  handler?: string;
  after?: string;
}

interface Props {
  jobs: Job[];
  canManage: boolean;
  nextCursor: string;
  currentParams: FilterParams;
}

function StatusFilterPills({ current, orgId, handler }: {
  current?: string;
  orgId?: string;
  handler?: string;
}) {
  return (
    <div className="flex flex-wrap items-center gap-2">
      <span className="text-xs text-muted-foreground shrink-0">Status:</span>
      {ALL_STATUSES.map((s) => {
        const isActive = current === s;
        const p = new URLSearchParams();
        if (orgId) p.set("org_id", orgId);
        if (handler) p.set("handler", handler);
        if (!isActive) p.set("status", s);
        return (
          <Link
            key={s}
            href={`${ROUTES.ADMIN_JOBS}?${p.toString()}`}
            className={cn(
              "text-xs px-2 py-0.5 rounded border transition-colors",
              isActive
                ? "bg-primary text-primary-foreground border-primary"
                : "border-border text-muted-foreground hover:border-primary/40 hover:text-foreground",
            )}
          >
            {s}
          </Link>
        );
      })}
    </div>
  );
}

export function JobsTable({ jobs, canManage, nextCursor, currentParams }: Props) {
  const nextParams = new URLSearchParams();
  if (currentParams.org_id) nextParams.set("org_id", currentParams.org_id);
  if (currentParams.status) nextParams.set("status", currentParams.status);
  if (currentParams.handler) nextParams.set("handler", currentParams.handler);
  if (nextCursor) nextParams.set("after", nextCursor);

  return (
    <>
      <StatusFilterPills
        current={currentParams.status}
        orgId={currentParams.org_id}
        handler={currentParams.handler}
      />

      {jobs.length === 0 ? (
        <div className="empty-state mt-6">
          <p className="text-muted-foreground">No jobs match the current filters.</p>
        </div>
      ) : (
        <div className="table-responsive mt-4">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-muted-foreground">
                <th className="pb-2 pr-6 font-medium">Handler</th>
                <th className="pb-2 pr-4 font-medium">Org</th>
                <th className="pb-2 pr-4 font-medium">Status</th>
                <th className="pb-2 pr-4 font-medium">Priority</th>
                <th className="pb-2 pr-4 font-medium">Created</th>
                {canManage && <th className="pb-2 font-medium">Actions</th>}
              </tr>
            </thead>
            <tbody>
              {jobs.map((job) => (
                <tr key={job.id} className="border-b border-border last:border-0 hover:bg-muted/30 transition-colors">
                  <td className="py-3 pr-6">
                    {job.org_id ? (
                      <Link
                        href={ROUTES.adminJob(job.id)}
                        className="font-mono text-xs hover:text-primary hover:underline"
                      >
                        {job.handler}
                      </Link>
                    ) : (
                      <span className="font-mono text-xs">{job.handler}</span>
                    )}
                  </td>
                  <td className="py-3 pr-4 text-muted-foreground">
                    {job.org_id ? (
                      <Link
                        href={`${ROUTES.ADMIN_JOBS}?org_id=${job.org_id}`}
                        className="hover:underline"
                      >
                        {job.org_id.slice(0, 8)}…
                      </Link>
                    ) : (
                      <span className="text-muted-foreground">—</span>
                    )}
                  </td>
                  <td className="py-3 pr-4">
                    <Badge variant={STATUS_VARIANT[job.status]}>{job.status}</Badge>
                  </td>
                  <td className="py-3 pr-4 text-muted-foreground">
                    {PRIORITY_LABEL[job.priority] ?? job.priority}
                  </td>
                  <td className="py-3 pr-4 text-muted-foreground">
                    {fmt(job.created_at)}
                  </td>
                  {canManage && (
                    <td className="py-3">
                      <div className="flex items-center gap-1">
                        {(job.status === "failed" || job.status === "dead") && (
                          <form action={forceRetryJobAction.bind(null, job.id)}>
                            <Button type="submit" variant="ghost" size="sm" className="h-7 px-2">
                              Retry
                            </Button>
                          </form>
                        )}
                        {(job.status === "pending" || job.status === "queued") && (
                          <form action={cancelJobAction.bind(null, job.id)}>
                            <Button
                              type="submit"
                              variant="ghost"
                              size="sm"
                              className="h-7 px-2 text-destructive hover:text-destructive"
                            >
                              Cancel
                            </Button>
                          </form>
                        )}
                      </div>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {nextCursor && (
        <div className="mt-4 flex justify-center">
          <Button asChild variant="outline">
            <Link href={`${ROUTES.ADMIN_JOBS}?${nextParams.toString()}`}>
              Load more
            </Link>
          </Button>
        </div>
      )}
    </>
  );
}
