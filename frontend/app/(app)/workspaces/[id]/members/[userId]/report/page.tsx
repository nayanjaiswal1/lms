import type { Metadata } from "next";

import { Badge } from "@/components/ui/badge";
import { IssueCertificateDialog } from "@/components/workspace/reports/issue-certificate-dialog";
import { getMemberReport } from "@/lib/workspace/phase5-server";
import { getWorkspace } from "@/lib/workspace/server";
import { PROJECT_ROLE_LABEL } from "@/lib/workspace/roles";

export const metadata: Metadata = {
  title: "Member Report",
};

interface PageProps {
  params: Promise<{ id: string; userId: string }>;
}

const STAT_ROWS: { label: string; key: keyof Awaited<ReturnType<typeof getMemberReport>> }[] = [
  { label: "Items owned", key: "items_owned" },
  { label: "Items done (owned)", key: "items_done_owned" },
  { label: "Code reviews given", key: "items_reviewed" },
  { label: "Items tested", key: "items_tested" },
  { label: "Reopens caused", key: "reopens_caused" },
  { label: "Doc approvals", key: "doc_approvals" },
  { label: "MRs opened", key: "mrs_opened" },
  { label: "MRs merged", key: "mrs_merged" },
  { label: "Review comments", key: "review_comments" },
  { label: "Minutes logged", key: "minutes_logged" },
  { label: "Meetings attended", key: "meetings_attended" },
  { label: "Meetings missed", key: "meetings_missed" },
  { label: "Standups posted", key: "standups_posted" },
];

export default async function MemberReportPage({ params }: PageProps) {
  const { id, userId } = await params;
  const [workspace, report] = await Promise.all([getWorkspace(id), getMemberReport(id, userId)]);
  const canIssueCertificate = workspace.my_role === "owner" && workspace.project_status === "completed";

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="page-title">{report.person.name}&apos;s report</h1>
          <p className="text-sm text-muted-foreground">{PROJECT_ROLE_LABEL[report.role]}</p>
        </div>
        <div className="flex items-center gap-2">
          {report.certificate_id && <Badge variant="secondary">Certificate issued</Badge>}
          {canIssueCertificate && <IssueCertificateDialog hasCertificate={Boolean(report.certificate_id)} userId={userId} userName={report.person.name} workspaceId={id} />}
        </div>
      </div>

      {report.peer_rating !== null && (
        <div className="card-base">
          <p className="text-xs text-muted-foreground">Peer rating</p>
          <p className="text-2xl font-semibold">{report.peer_rating.toFixed(1)} / 5</p>
        </div>
      )}

      <div className="grid-stats card-base">
        {STAT_ROWS.map(({ label, key }) => (
          <div key={key}>
            <p className="text-xs text-muted-foreground">{label}</p>
            <p className="text-lg font-semibold">{report[key] as number}</p>
          </div>
        ))}
      </div>

      <p className="text-sm text-muted-foreground">
        Showcase opt-in: {report.showcase_opt_in ? "Yes" : "No"}
      </p>
    </div>
  );
}
