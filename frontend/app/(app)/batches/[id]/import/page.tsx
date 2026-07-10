import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { CheckCircle2, XCircle } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { getBatch, getBatchImportReport, getOrgId, getOrgMembersAll } from "@/lib/server/batches";
import { getCourses } from "@/lib/server/courses";
import { fetchJob } from "@/lib/jobs/server";
import ROUTES from "@/lib/routes";
import { ImportWizard } from "@/app/(app)/batches/[id]/import/import-wizard";

interface Props {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ job?: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { id } = await params;
  const batch = await getBatch(id).catch(() => null);
  return { title: batch ? `Import students — ${batch.name}` : "Import students — MindForge" };
}

export default async function BatchImportPage({ params, searchParams }: Props) {
  const { id } = await params;
  const { job: jobId } = await searchParams;

  const orgId = await getOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const batch = await getBatch(id).catch(() => null);
  if (!batch) notFound();

  if (jobId) {
    return <ImportProgress batchId={id} batchName={batch.name} jobId={jobId} orgId={orgId} />;
  }

  const [courses, orgMembers] = await Promise.all([
    getCourses().catch(() => []),
    getOrgMembersAll(orgId).catch(() => []),
  ]);

  return (
    <main className="page-container-sm py-8 space-y-6">
      <div>
        <Link className="text-sm text-muted-foreground hover:text-foreground" href={ROUTES.batch(id)}>
          ← {batch.name}
        </Link>
        <h1 className="page-title mt-2">Bulk import students</h1>
      </div>
      <ImportWizard batchId={id} courses={courses} orgMembers={orgMembers} />
    </main>
  );
}

async function ImportProgress({ batchId, batchName, jobId, orgId }: { batchId: string; batchName: string; jobId: string; orgId: string }) {
  const detail = await fetchJob(orgId, jobId).catch(() => null);
  if (!detail) notFound();

  const { job } = detail;
  const isTerminal = ["success", "failed", "dead", "cancelled"].includes(job.status);
  const report = isTerminal ? await getBatchImportReport(batchId).catch(() => null) : null;

  return (
    <main className="page-container-sm py-8 space-y-6">
      <div>
        <Link className="text-sm text-muted-foreground hover:text-foreground" href={ROUTES.batch(batchId)}>
          ← {batchName}
        </Link>
        <h1 className="page-title mt-2">Import progress</h1>
      </div>

      <div className="card-base p-6 space-y-4">
        <div className="flex items-center gap-2">
          {job.status === "success" && <CheckCircle2 aria-hidden className="h-5 w-5 text-success" />}
          {(job.status === "failed" || job.status === "dead") && <XCircle aria-hidden className="h-5 w-5 text-destructive" />}
          <span className="font-medium capitalize">{isTerminal ? job.status : "Processing…"}</span>
        </div>

        {!isTerminal && (
          <p className="text-sm text-muted-foreground">
            This import is still running in the background. Refresh this page to check progress.
          </p>
        )}
        {job.last_error && <p className="text-sm text-destructive">{job.last_error}</p>}

        {report && (
          <div className="space-y-4 pt-2">
            <div className="flex flex-wrap gap-2">
              {Object.entries(report.counts).map(([status, count]) => (
                <Badge key={status} variant="secondary">
                  {count} {status.replace(/_/g, " ")}
                </Badge>
              ))}
            </div>

            {report.failed_rows.length > 0 && (
              <div className="table-responsive">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-border text-left text-xs text-muted-foreground">
                      <th className="pb-2 pr-3 font-medium">Name</th>
                      <th className="pb-2 pr-3 font-medium">Email</th>
                      <th className="pb-2 font-medium">Error</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {report.failed_rows.map((row) => (
                      <tr key={row.email}>
                        <td className="py-2 pr-3">{row.full_name}</td>
                        <td className="py-2 pr-3 text-muted-foreground">{row.email}</td>
                        <td className="py-2 text-destructive">{row.error_message}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        <div className="flex gap-3 pt-2">
          <Button asChild size="sm" variant="outline">
            <Link href={ROUTES.batchImport(batchId)}>Run another import</Link>
          </Button>
          <Button asChild size="sm">
            <Link href={ROUTES.batch(batchId)}>Back to batch</Link>
          </Button>
        </div>
      </div>
    </main>
  );
}
