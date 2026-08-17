import { Breadcrumb } from "@/components/shared/breadcrumb";
import { fetchWorkerHealth } from "@/lib/jobs/admin-server";
import { WorkersClient } from "@/app/platform/jobs/workers/workers-client";
import ROUTES from "@/lib/routes";

export default async function PlatformWorkersPage() {
  const data = await fetchWorkerHealth();

  return (
    <div className="page-container">
      <Breadcrumb items={[{ href: ROUTES.PLATFORM_JOBS, label: "Jobs" }, { label: "Worker Health" }]} />

      <div className="page-header">
        <div>
          <h1 className="page-title">Worker Health</h1>
          <p className="text-muted-foreground mt-1">
            Live view of all job worker instances. Updates every 15 seconds.
          </p>
        </div>
      </div>

      <section className="mt-8">
        <WorkersClient initialData={data} />
      </section>
    </div>
  );
}
