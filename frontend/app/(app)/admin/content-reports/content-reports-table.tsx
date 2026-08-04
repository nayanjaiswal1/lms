"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { CONTENT_REPORT_STATUS_OPTIONS } from "@/lib/constants";
import { resolveContentReportAction } from "@/app/(app)/admin/content-reports/actions";

export interface ContentReport {
  id: string;
  content_type: string;
  content_id: string;
  reason: string;
  description: string | null;
  status: string;
  reporter_id: string;
  resolution_note: string | null;
  created_at: string;
}

const STATUS_BADGE: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  pending: "outline",
  reviewing: "secondary",
  removed: "destructive",
  dismissed: "default",
};

interface ContentReportsTableProps {
  reports: ContentReport[];
}

export function ContentReportsTable({ reports }: ContentReportsTableProps) {
  const [active, setActive] = useState<ContentReport | null>(null);
  const [draft, setDraft] = useState<{ status: string; note: string; pending: boolean }>({
    status: "",
    note: "",
    pending: false,
  });

  function openResolve(report: ContentReport) {
    setActive(report);
    setDraft({ status: report.status, note: report.resolution_note ?? "", pending: false });
  }

  async function handleResolve() {
    if (!active) return;
    setDraft((d) => ({ ...d, pending: true }));
    const result = await resolveContentReportAction(active.id, draft.status, draft.note);
    if (result.error) {
      setDraft((d) => ({ ...d, pending: false }));
      toast.error(result.error);
      return;
    }
    toast.success("Report resolved.");
    setActive(null);
  }

  return (
    <>
      <div className="table-responsive">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-muted-foreground">
              <th className="pb-2 pr-4 font-medium">When</th>
              <th className="pb-2 pr-4 font-medium">Content</th>
              <th className="pb-2 pr-4 font-medium">Reason</th>
              <th className="pb-2 pr-4 font-medium">Status</th>
              <th className="pb-2 font-medium">Action</th>
            </tr>
          </thead>
          <tbody>
            {reports.map((rp) => (
              <tr className="border-b border-border last:border-0 whitespace-nowrap" key={rp.id}>
                <td className="py-3 pr-4 text-muted-foreground">
                  {new Date(rp.created_at).toLocaleString()}
                </td>
                <td className="py-3 pr-4">
                  <span className="text-muted-foreground">{rp.content_type} / </span>
                  <code className="text-xs">{rp.content_id}</code>
                </td>
                <td className="py-3 pr-4">{rp.reason}</td>
                <td className="py-3 pr-4">
                  <Badge variant={STATUS_BADGE[rp.status] ?? "outline"}>{rp.status}</Badge>
                </td>
                <td className="py-3">
                  <Button size="sm" variant="outline" onClick={() => openResolve(rp)}>
                    Review
                  </Button>
                </td>
              </tr>
            ))}
            {reports.length === 0 && (
              <tr>
                <td className="py-12 text-center text-muted-foreground" colSpan={5}>
                  No content reports.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <Dialog open={active !== null} onOpenChange={(open) => !open && setActive(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Resolve report</DialogTitle>
          </DialogHeader>
          {active && (
            <div className="form-stack">
              <div className="text-sm text-muted-foreground">
                <p>
                  <span className="font-medium text-foreground">{active.content_type}</span> /{" "}
                  <code className="text-xs">{active.content_id}</code>
                </p>
                <p>Reason: {active.reason}</p>
                {active.description && <p>&quot;{active.description}&quot;</p>}
              </div>

              <Select
                value={draft.status}
                onValueChange={(status) => setDraft((d) => ({ ...d, status }))}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Choose a resolution" />
                </SelectTrigger>
                <SelectContent>
                  {CONTENT_REPORT_STATUS_OPTIONS.map((opt) => (
                    <SelectItem key={opt.value} value={opt.value}>
                      {opt.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              <Textarea
                placeholder="Resolution note (visible to other staff)"
                value={draft.note}
                onChange={(e) => setDraft((d) => ({ ...d, note: e.target.value }))}
              />
            </div>
          )}
          <DialogFooter>
            <Button disabled={draft.pending || !draft.status} onClick={handleResolve}>
              {draft.pending ? <Loader2 aria-hidden className="animate-spin" /> : null}
              Save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
