import Link from "next/link";
import { Button } from "@/components/ui/button";
import { pauseOrgJobsAction } from "@/app/(app)/admin/jobs/actions";
import ROUTES from "@/lib/routes";
import type { OrgJobStats } from "@/lib/jobs/types";

interface Props {
  orgs: OrgJobStats[];
  activeOrgId?: string;
}

export function OrgStatsTable({ orgs, activeOrgId }: Props) {
  if (orgs.length === 0) {
    return (
      <div className="empty-state">
        <p className="text-muted-foreground">No organisations with jobs found.</p>
      </div>
    );
  }

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
            <th className="pb-2 pr-4 font-medium">Quota (concurrent / queued)</th>
            <th className="pb-2 font-medium">Actions</th>
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
                  <Link
                    href={`${ROUTES.ADMIN_JOBS}?org_id=${org.org_id}&status=failed`}
                    className="text-destructive font-medium hover:underline"
                  >
                    {org.failed}
                  </Link>
                ) : (
                  <span className="text-muted-foreground">{org.failed}</span>
                )}
              </td>
              <td className="py-3 pr-4">
                {org.dead > 0 ? (
                  <Link
                    href={`${ROUTES.ADMIN_JOBS}?org_id=${org.org_id}&status=dead`}
                    className="text-destructive font-medium hover:underline"
                  >
                    {org.dead}
                  </Link>
                ) : (
                  <span className="text-muted-foreground">{org.dead}</span>
                )}
              </td>
              <td className="py-3 pr-4 text-muted-foreground">
                {org.quota.max_concurrent} / {org.quota.max_queued}
                <Link
                  href={ROUTES.adminOrgQuotas(org.org_id)}
                  className="ml-3 text-xs text-primary hover:underline"
                >
                  Edit
                </Link>
              </td>
              <td className="py-3">
                {(org.queued > 0 || org.running === 0) && (
                  <form action={pauseOrgJobsAction.bind(null, org.org_id)}>
                    <Button
                      type="submit"
                      variant="ghost"
                      size="sm"
                      className="text-destructive hover:text-destructive h-7 px-2"
                    >
                      Pause All
                    </Button>
                  </form>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
