import { Breadcrumb } from "@/components/shared/breadcrumb";
import { fetchWorkerHealth } from "@/lib/jobs/admin-server";
import { WorkersClient } from "@/app/platform/jobs/workers/workers-client";
import ROUTES from "@/lib/routes";
import { PageHeader } from "@/components/shared/page-header";

export default async function PlatformWorkersPage() {
  const data = await fetchWorkerHealth();

  return (
    <div className="page-container">
      <Breadcrumb items={[{ href: ROUTES.PLATFORM_JOBS, label: "Jobs" }, { label: "Worker Health" }]} />

      <PageHeader title="Worker Health" description="Live view of all job worker instances. Updates every 15 seconds." />

      <section className="mt-8">
        <WorkersClient initialData={data} />
      </section>
    </div>
  );
}
