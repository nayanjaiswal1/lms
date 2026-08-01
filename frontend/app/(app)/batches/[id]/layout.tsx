import { notFound, redirect } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { BatchAvatar } from "@/components/batches/batch-avatar";
import { BatchBreadcrumb } from "@/app/(app)/batches/[id]/batch-breadcrumb";
import { BatchNameProvider } from "@/app/(app)/batches/[id]/batch-name-context";
import { BatchTabs } from "@/app/(app)/batches/[id]/batch-tabs";
import { ScheduleBatchSession } from "@/app/(app)/batches/[id]/schedule-batch-session";
import { getBatch, getOrgId } from "@/lib/server/batches";
import { getCurrentOrgType } from "@/lib/orgs/server";
import { resolveTerminology } from "@/lib/terminology";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
  children: React.ReactNode;
}

export async function generateMetadata({ params }: Props) {
  const { id } = await params;
  const batch = await getBatch(id).catch(() => null);
  return { title: batch ? `${batch.name} — MindForge` : "Batch — MindForge" };
}

export default async function BatchLayout({ params, children }: Props) {
  const { id } = await params;
  const [orgId, orgType] = await Promise.all([getOrgId(), getCurrentOrgType()]);

  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const batch = await getBatch(id).catch(() => null);
  if (!batch) notFound();

  const t = resolveTerminology(orgType);

  const testsLabel = `${t.class_} Tests`;

  return (
    <main className="page-container">
      <BatchBreadcrumb batchId={id} batchName={batch.name} testsLabel={testsLabel} />
      <div className="page-header">
        <div className="flex items-center gap-3">
          <BatchAvatar batchId={batch.id} imageUrl={batch.image_url} name={batch.name} size="md" />
          <div className="flex flex-col gap-2">
            <div className="flex items-center gap-2">
              <h1 className="section-title">{batch.name}</h1>
              <Badge variant={batch.status === "active" ? "default" : "secondary"}>
                {batch.status}
              </Badge>
            </div>
            {batch.description && (
              <p className="text-sm text-muted-foreground">{batch.description}</p>
            )}
            {(batch.starts_at || batch.ends_at) && (
              <p className="text-xs text-muted-foreground">
                {batch.starts_at && new Date(batch.starts_at).toLocaleDateString()}
                {batch.ends_at && ` – ${new Date(batch.ends_at).toLocaleDateString()}`}
              </p>
            )}
          </div>
        </div>
        <ScheduleBatchSession batchId={id} />
      </div>

      <BatchTabs batchId={id} testsLabel={testsLabel} />

      <BatchNameProvider name={batch.name}>
        <div>{children}</div>
      </BatchNameProvider>
    </main>
  );
}
