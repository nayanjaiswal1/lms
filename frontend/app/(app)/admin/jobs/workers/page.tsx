import Link from "next/link";
import { notFound } from "next/navigation";
import { Button } from "@/components/ui/button";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { fetchWorkerHealth } from "@/lib/server/admin-jobs";
import { WorkersClient } from "@/app/(app)/admin/jobs/workers/workers-client";
import ROUTES from "@/lib/routes";

export default async function WorkersPage() {
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.ADMIN.VIEW_JOBS)) notFound();

  const data = await fetchWorkerHealth();

  return (
    <div className="page-container py-8">
      <div className="page-header">
        <div>
          <h1 className="page-title">Worker Health</h1>
          <p className="text-muted-foreground mt-1">
            Live view of all job worker instances. Updates every 15 seconds.
          </p>
        </div>
        <Button asChild variant="outline">
          <Link href={ROUTES.ADMIN_JOBS}>Back to Jobs</Link>
        </Button>
      </div>

      <section className="mt-8">
        <WorkersClient initialData={data} />
      </section>
    </div>
  );
}
