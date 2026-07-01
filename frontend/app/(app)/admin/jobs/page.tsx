import Link from "next/link";
import { notFound } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { fetchAdminJobs, fetchPlatformStats } from "@/lib/server/admin-jobs";
import { OrgStatsTable } from "@/app/(app)/admin/jobs/org-stats-table";
import { JobsTable } from "@/app/(app)/admin/jobs/jobs-table";
import ROUTES from "@/lib/routes";

interface PageProps {
  searchParams: Promise<{
    org_id?: string;
    status?: string;
    handler?: string;
    after?: string;
  }>;
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

  const activeOrgName = statsData.per_org.find(
    (o) => o.org_id === params.org_id,
  )?.org_name;

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

      <section className="mt-8">
        <h2 className="section-title mb-4">Organisation Stats</h2>
        <OrgStatsTable orgs={statsData.per_org} activeOrgId={params.org_id} />
      </section>

      <section className="mt-8">
        <div className="flex flex-wrap items-center gap-3 mb-4">
          <h2 className="section-title">Jobs</h2>
          {activeOrgName && (
            <Badge variant="secondary">Org: {activeOrgName}</Badge>
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
