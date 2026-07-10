import Link from "next/link";
import { Button } from "@/components/ui/button";
import { fetchWorkerHealth } from "@/lib/jobs/admin-server";
import { WorkersClient } from "@/app/platform/jobs/workers/workers-client";
import ROUTES from "@/lib/routes";

export default async function PlatformWorkersPage() {
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
          <Link href={ROUTES.PLATFORM_JOBS}>Back to Jobs</Link>
        </Button>
      </div>

      <section className="mt-8">
        <WorkersClient initialData={data} />
      </section>
    </div>
  );
}
