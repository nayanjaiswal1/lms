"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Download } from "lucide-react";

import { Button } from "@/components/ui/button";
import { exportWorkspaceCSVAction } from "@/lib/workspace/phase5-actions";
import type { ExportKind } from "@/lib/workspace/types";

const KINDS: { kind: ExportKind; label: string }[] = [
  { kind: "items", label: "Items" },
  { kind: "time_logs", label: "Time logs" },
  { kind: "members", label: "Members" },
];

/** Manager+ (contract-phase5.md 5d) — kept on the dashboard rather than the
 * owner-only Settings page, since this export is manager-gated at the API,
 * not owner-gated, and Settings never opens for a non-owner manager to reach
 * it from there. */
export function CSVExportButtons({ workspaceId }: { workspaceId: string }) {
  const [pending, setPending] = useState<ExportKind | null>(null);

  async function download(kind: ExportKind) {
    setPending(kind);
    const result = await exportWorkspaceCSVAction(workspaceId, kind);
    setPending(null);
    if (result.error || result.data === undefined) {
      toast.error(result.error ?? "Export failed.");
      return;
    }
    const blob = new Blob([result.data], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${workspaceId}-${kind}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  }

  return (
    <div className="flex flex-wrap gap-2">
      {KINDS.map(({ kind, label }) => (
        <Button disabled={pending !== null} key={kind} size="sm" variant="outline" onClick={() => void download(kind)}>
          <Download aria-hidden className="mr-1.5 h-3.5 w-3.5" />
          {pending === kind ? "Exporting…" : `Export ${label}`}
        </Button>
      ))}
    </div>
  );
}
