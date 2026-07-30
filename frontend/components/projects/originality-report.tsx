"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { ScanSearch } from "lucide-react";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { OriginalityMatchRow } from "@/components/projects/originality-match-row";
import { runOriginalityScanAction } from "@/app/(app)/projects/actions";
import { ORIGINALITY_STATUS_LABEL, ORIGINALITY_STATUS_VARIANT } from "@/lib/constants";
import type { OriginalityReportView } from "@/lib/projects/types";

const POLL_INTERVAL_MS = 10_000;

// Auto-refreshes the page while the latest scan is still pending/running —
// same setInterval(() => router.refresh()) shape as EvalPoller
// (components/assessments/eval-poller.tsx), this codebase's established
// convention for "async job in progress, poll for completion" on a
// server-rendered page. Kept as a private helper here (not its own file)
// since it's a one-line wrapper only OriginalityReport ever mounts — mirrors
// team-card.tsx's own private RenameTeamDialog helper.
function ScanPoller({ status }: { status: string }) {
  const router = useRouter();

  React.useEffect(() => {
    if (status !== "pending" && status !== "running") return;
    const id = setInterval(() => router.refresh(), POLL_INTERVAL_MS);
    return () => clearInterval(id);
  }, [status, router]);

  return null;
}

interface OriginalityReportProps {
  assignmentId: string;
  reports: OriginalityReportView[];
  teamsById: Record<string, string>;
}

export function OriginalityReport({ assignmentId, reports, teamsById }: OriginalityReportProps) {
  const router = useRouter();
  const [pending, setPending] = React.useState(false);
  const latest = reports[0];

  async function handleRunScan() {
    setPending(true);
    const result = await runOriginalityScanAction(assignmentId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Originality scan started — this runs in the background.");
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-4">
      {latest && <ScanPoller status={latest.status} />}

      <div className="flex items-center justify-between gap-4">
        <p className="text-sm text-muted-foreground">
          Compares every team&apos;s files against each other and the template project, flagging pairs at or above 60% similarity.
        </p>
        <Button disabled={pending} size="sm" onClick={() => void handleRunScan()}>
          <ScanSearch aria-hidden className="mr-1.5 h-3.5 w-3.5" />
          {pending ? "Starting…" : "Run originality scan"}
        </Button>
      </div>

      {reports.length === 0 ? (
        <p className="empty-state text-sm text-muted-foreground">No scans run yet.</p>
      ) : (
        <div className="flex flex-col gap-4">
          {reports.map((report) => (
            <article className="card-base flex flex-col gap-3 p-4" key={report.id}>
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <Badge variant={ORIGINALITY_STATUS_VARIANT[report.status] ?? "outline"}>
                    {ORIGINALITY_STATUS_LABEL[report.status] ?? report.status}
                  </Badge>
                  <span className="text-xs text-muted-foreground">
                    Requested {new Date(report.requested_at).toLocaleString()}
                  </span>
                </div>
                {report.status === "complete" && (
                  <span className="text-xs text-muted-foreground">
                    {report.teams_scanned} team{report.teams_scanned === 1 ? "" : "s"} · {report.files_scanned} files scanned
                  </span>
                )}
              </div>

              {(report.status === "pending" || report.status === "running") && (
                <p className="text-sm text-muted-foreground">Scan running — this page refreshes automatically, check back shortly.</p>
              )}

              {report.status === "failed" && report.error && <p className="text-sm text-destructive">{report.error}</p>}

              {report.status === "complete" && (
                report.matches.length === 0 ? (
                  <p className="text-sm text-muted-foreground">No matches at or above the similarity threshold.</p>
                ) : (
                  <div className="table-responsive">
                    <table className="w-full text-left">
                      <thead>
                        <tr className="border-b border-border text-xs text-muted-foreground">
                          <th className="pb-2 pr-4 font-medium">Teams</th>
                          <th className="pb-2 pr-4 font-medium">Files</th>
                          <th className="pb-2 pr-4 font-medium">Similarity</th>
                          <th className="pb-2 font-medium">Sample</th>
                        </tr>
                      </thead>
                      <tbody>
                        {report.matches.map((match) => (
                          <OriginalityMatchRow key={match.id} match={match} teamsById={teamsById} />
                        ))}
                      </tbody>
                    </table>
                  </div>
                )
              )}
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
