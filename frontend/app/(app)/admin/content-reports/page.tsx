import { notFound } from "next/navigation";

import { apiGet } from "@/lib/server/api";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { ContentReportsTable, type ContentReport } from "@/app/(app)/admin/content-reports/content-reports-table";
import { PageHeader } from "@/components/shared/page-header";

interface SearchParams {
  status?: string;
  content_type?: string;
}

async function fetchReports(params: SearchParams): Promise<ContentReport[]> {
  const qs = new URLSearchParams();
  if (params.status) qs.set("status", params.status);
  if (params.content_type) qs.set("content_type", params.content_type);

  try {
    const body = await apiGet<{ reports: ContentReport[] }>(`/api/content-reports?${qs.toString()}`);
    return body.reports ?? [];
  } catch {
    return [];
  }
}

export default async function ContentReportsPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.MODERATION.MANAGE)) {
    notFound();
  }

  const sp = await searchParams;
  const reports = await fetchReports(sp);

  return (
    <div className="page-container">
      <PageHeader title="Content Reports" description="Reports of illegal, infringing, or abusive content flagged by members." />

      <div className="mt-8">
        <ContentReportsTable reports={reports} />
      </div>
    </div>
  );
}
