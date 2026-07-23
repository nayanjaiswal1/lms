"use client";

import * as React from "react";
import { CheckCircle2, RefreshCw, XCircle } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { getImportJobStatusAction, type ImportJobStatus } from "@/app/(app)/batches/actions";

interface ImportProgressPanelProps {
  batchId: string;
  jobId: string;
  initialStatus: ImportJobStatus;
  onRunAnother: () => void;
}

export function ImportProgressPanel({ batchId, jobId, initialStatus, onRunAnother }: ImportProgressPanelProps) {
  const [status, setStatus] = React.useState(initialStatus);
  const [checking, setChecking] = React.useState(false);

  async function checkStatus() {
    setChecking(true);
    const result = await getImportJobStatusAction(batchId, jobId);
    setChecking(false);
    if (result.ok && result.data) setStatus(result.data);
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        {status.status === "success" && <CheckCircle2 aria-hidden className="h-5 w-5 text-success" />}
        {(status.status === "failed" || status.status === "dead") && (
          <XCircle aria-hidden className="h-5 w-5 text-destructive" />
        )}
        <span className="font-medium capitalize">{status.isTerminal ? status.status : "Processing…"}</span>
      </div>

      {!status.isTerminal && (
        <div className="flex items-center justify-between gap-3 rounded-md border border-dashed border-border p-3">
          <p className="text-sm text-muted-foreground">This import is still running in the background.</p>
          <Button disabled={checking} size="sm" variant="outline" onClick={() => void checkStatus()}>
            <RefreshCw aria-hidden className={`mr-1.5 h-4 w-4 ${checking ? "animate-spin" : ""}`} />
            {checking ? "Checking…" : "Check status"}
          </Button>
        </div>
      )}
      {status.lastError && <p className="text-sm text-destructive">{status.lastError}</p>}

      {status.report && (
        <div className="space-y-4 pt-2">
          <div className="flex flex-wrap gap-2">
            {Object.entries(status.report.counts).map(([s, count]) => (
              <Badge key={s} variant="secondary">
                {count} {s.replace(/_/g, " ")}
              </Badge>
            ))}
          </div>

          {status.report.failed_rows.length > 0 && (
            <div className="table-responsive max-h-56 overflow-y-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border text-left text-xs text-muted-foreground">
                    <th className="pb-2 pr-3 font-medium">Name</th>
                    <th className="pb-2 pr-3 font-medium">Email</th>
                    <th className="pb-2 font-medium">Error</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {status.report.failed_rows.map((row) => (
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
        <Button size="sm" variant="outline" onClick={onRunAnother}>
          Run another import
        </Button>
      </div>
    </div>
  );
}
