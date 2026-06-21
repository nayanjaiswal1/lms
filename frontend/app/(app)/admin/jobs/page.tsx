import Link from "next/link";
import { notFound } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import {
  fetchAdminJobs,
  fetchPlatformStats,
} from "@/lib/server/admin-jobs";
import { forceRetryJobAction } from "@/app/(app)/admin/jobs/actions";
import type { Job, OrgJobStats, JobStatus } from "@/lib/jobs/types";
import ROUTES from "@/lib/routes";

interface PageProps {
  searchParams: Promise<{
    org_id?: string;
    status?: string;
    handler?: string;
    after?: string;
  }>;
}

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

function fmt(iso: string): string {
  return new Date(iso).toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default async function AdminJobsPage({ searchParams }: PageProps) {
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.ADMIN.VIEW_JOBS)) notFound();

  const params = await searchParams;
  const canManage = myPerms.includes(PERMISSIONS.ADMIN.MANAGE_JOBS);

  const [statsData, jobsData] = await Promise.all([
    fetchPlatformStats(),
    fetchAdminJobs({
      org_id:  params.org_id,
      status:  params.status,
      handler: params.handler,
      after:   params.after,
      limit:   50,
    }),
  ]);

  return (
    <div className="page-container py-8">
      <div className="page-header">
        <div>
          <h1 className="page-title">Platform Jobs</h1>
          <p className="text-muted-foreground mt-1">
            Monitor and manage background jobs across all organisations.
          </p>
        </div>
        <Button asChild variant="outline">
          <Link href={ROUTES.ADMIN_JOBS_WORKERS}>Worker Health</Link>
        </Button>
      </div>

      {/* Platform stats per org */}
      <section className="mt-8">
        <h2 className="section-title mb-4">Organisation Stats</h2>
        <OrgStatsTable
          orgs={statsData.per_org}
          activeOrgId={params.org_id}
        />
      </section>

      {/* Filters row */}
      <section className="mt-8">
        <div className="flex flex-wrap items-center gap-3 mb-4">
          <h2 className="section-title">Jobs</h2>
          {params.org_id && (
            <Badge variant="secondary">
              Org: {statsData.per_org.find((o) => o.org_id === params.org_id)?.org_name ?? params.org_id}
            </Badge>
          )}
          {params.status && (
            <Badge variant="secondary">Status: {params.status}</Badge>
          )}
          {params.handler && (
            <Badge variant="secondary">Handler: {params.handler}</Badge>
          )}
          {(params.org_id ?? params.status ?? params.handler) && (
            <Button asChild variant="ghost" size="sm">
              <Link href={ROUTES.ADMIN_JOBS}>Clear filters</Link>
            </Button>
          )}
        </div>
        <JobsTable
          jobs={jobsData.jobs}
          canManage={canManage}
          nextCursor={jobsData.next_cursor}
          currentParams={params}
        />
      </section>
    </div>
  );
}

function OrgStatsTable({
  orgs,
  activeOrgId,
}: {
  orgs: OrgJobStats[];
  activeOrgId?: string;
}) {
  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-muted-foreground">
            <th className="pb-2 pr-6 font-medium">Organisation</th>
            <th className="pb-2 pr-4 font-medium">Running</th>
            <th className="pb-2 pr-4 font-medium">Queued</th>
            <th className="pb-2 pr-4 font-medium">Failed</th>
            <th className="pb-2 pr-4 font-medium">Dead</th>
            <th className="pb-2 font-medium">Quota (concurrent / queued)</th>
          </tr>
        </thead>
        <tbody>
          {orgs.map((org) => (
            <tr
              key={org.org_id}
              className={`border-b border-border last:border-0 transition-colors ${
                activeOrgId === org.org_id ? "bg-accent/40" : "hover:bg-muted/50"
              }`}
            >
              <td className="py-3 pr-6">
                <Link
                  href={`${ROUTES.ADMIN_JOBS}?org_id=${org.org_id}`}
                  className="font-medium hover:underline"
                >
                  {org.org_name}
                </Link>
              </td>
              <td className="py-3 pr-4">
                {org.running > 0 ? (
                  <span className="text-primary font-medium">{org.running}</span>
                ) : (
                  <span className="text-muted-foreground">{org.running}</span>
                )}
              </td>
              <td className="py-3 pr-4">{org.queued}</td>
              <td className="py-3 pr-4">
                {org.failed > 0 ? (
                  <span className="text-destructive font-medium">{org.failed}</span>
                ) : (
                  <span className="text-muted-foreground">{org.failed}</span>
                )}
              </td>
              <td className="py-3 pr-4">
                {org.dead > 0 ? (
                  <span className="text-destructive font-medium">{org.dead}</span>
                ) : (
                  <span className="text-muted-foreground">{org.dead}</span>
                )}
              </td>
              <td className="py-3 text-muted-foreground">
                {org.quota.max_concurrent} / {org.quota.max_queued}
                <Link
                  href={ROUTES.adminOrgQuotas(org.org_id)}
                  className="ml-3 text-xs text-primary hover:underline"
                >
                  Edit
                </Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function JobsTable({
  jobs,
  canManage,
  nextCursor,
  currentParams,
}: {
  jobs: Job[];
  canManage: boolean;
  nextCursor: string;
  currentParams: { org_id?: string; status?: string; handler?: string; after?: string };
}) {
  if (jobs.length === 0) {
    return (
      <div className="empty-state">
        <p className="text-muted-foreground">No jobs match the current filters.</p>
      </div>
    );
  }

  const nextParams = new URLSearchParams();
  if (currentParams.org_id) nextParams.set("org_id", currentParams.org_id);
  if (currentParams.status) nextParams.set("status", currentParams.status);
  if (currentParams.handler) nextParams.set("handler", currentParams.handler);
  if (nextCursor) nextParams.set("after", nextCursor);

  return (
    <>
      <div className="table-responsive">
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
              <tr key={job.id} className="border-b border-border last:border-0">
                <td className="py-3 pr-6">
                  <span className="font-mono text-xs">{job.handler}</span>
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
                  <Badge variant={STATUS_VARIANT[job.status]}>
                    {job.status}
                  </Badge>
                </td>
                <td className="py-3 pr-4 text-muted-foreground">
                  {PRIORITY_LABEL[job.priority] ?? job.priority}
                </td>
                <td className="py-3 pr-4 text-muted-foreground">
                  {fmt(job.created_at)}
                </td>
                {canManage && (
                  <td className="py-3">
                    {(job.status === "failed" || job.status === "dead") && (
                      <form action={forceRetryJobAction.bind(null, job.id)}>
                        <Button type="submit" variant="ghost" size="sm">
                          Retry
                        </Button>
                      </form>
                    )}
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

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
