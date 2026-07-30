import Link from "next/link";
import { notFound } from "next/navigation";
import { Button } from "@/components/ui/button";
import { fetchPlatformStats } from "@/lib/jobs/admin-server";
import { QuotaForm } from "@/app/platform/orgs/[id]/quotas/quota-form";
import ROUTES from "@/lib/routes";
import type { OrgJobStats } from "@/lib/jobs/types";

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function PlatformOrgQuotasPage({ params }: PageProps) {
  const { id: orgID } = await params;
  const statsData = await fetchPlatformStats();
  const orgStats: OrgJobStats | undefined = statsData.per_org.find(
    (o) => o.org_id === orgID,
  );

  if (!orgStats) notFound();

  return (
    <div className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">Edit Quota</h1>
          <p className="text-muted-foreground mt-1">
            Adjust job throughput limits for{" "}
            <strong>{orgStats.org_name}</strong>.
          </p>
        </div>
        <Button asChild variant="outline">
          <Link href={ROUTES.PLATFORM_JOBS}>Back to Jobs</Link>
        </Button>
      </div>

      {/* Current snapshot */}
      <section className="mt-8">
        <h2 className="section-title mb-4">Current Usage</h2>
        <div className="grid-stats">
          <StatCard label="Running" value={orgStats.running} />
          <StatCard label="Queued" value={orgStats.queued} />
          <StatCard label="Failed" value={orgStats.failed} highlight={orgStats.failed > 0} />
          <StatCard label="Dead" value={orgStats.dead} highlight={orgStats.dead > 0} />
        </div>
      </section>

      {/* Quota edit form */}
      <section className="mt-8">
        <h2 className="section-title mb-4">Quota Settings</h2>
        <QuotaForm orgID={orgID} current={orgStats.quota} />
      </section>
    </div>
  );
}

function StatCard({
  label,
  value,
  highlight = false,
}: {
  label: string;
  value: number;
  highlight?: boolean;
}) {
  return (
    <div className="card-base p-6">
      <p className="text-sm text-muted-foreground">{label}</p>
      <p className={`text-2xl font-bold mt-1 ${highlight ? "text-destructive" : "text-foreground"}`}>
        {value}
      </p>
    </div>
  );
}
