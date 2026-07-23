"use client";

import * as React from "react";
import { Pencil, RefreshCw, Trash2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { importValidateAction } from "@/app/(app)/batches/actions";
import type { Course } from "@/lib/server/courses";
import type { OrgMemberSummary } from "@/lib/server/batches";
import type { ImportMemberRow, ImportRowStatus } from "@/lib/server/batches";
import { ImportConfigPanel } from "@/app/(app)/batches/[id]/import/import-config-panel";
import { EditRowDialog } from "@/app/(app)/batches/[id]/import/edit-row-dialog";
import { toast } from "sonner";

const STATUS_LABEL: Record<ImportRowStatus, string> = {
  new: "New",
  existing_active: "Existing member",
  pending_invite: "Pending invite",
  duplicate_in_file: "Duplicate",
  invalid: "Invalid",
};

const STATUS_VARIANT: Record<ImportRowStatus, "default" | "secondary" | "destructive" | "outline"> = {
  new: "default",
  existing_active: "secondary",
  pending_invite: "outline",
  duplicate_in_file: "destructive",
  invalid: "destructive",
};

interface ReviewStepProps {
  batchId: string;
  rows: ImportMemberRow[];
  setRows: (rows: ImportMemberRow[]) => void;
  courses: Course[];
  orgMembers: OrgMemberSummary[];
  onConfirmed: (jobId: string) => void;
}

export function ReviewStep({ batchId, rows, setRows, courses, orgMembers, onConfirmed }: ReviewStepProps) {
  const [rechecking, setRechecking] = React.useState(false);
  const [editingIndex, setEditingIndex] = React.useState<number | null>(null);

  const counts = rows.reduce<Record<string, number>>((acc, r) => {
    acc[r.status] = (acc[r.status] ?? 0) + 1;
    return acc;
  }, {});
  const blockingCount = (counts.invalid ?? 0) + (counts.duplicate_in_file ?? 0);

  function updateRow(index: number, patch: Partial<ImportMemberRow>) {
    const next = rows.slice();
    next[index] = { ...next[index], ...patch };
    setRows(next);
  }

  function removeRow(index: number) {
    setRows(rows.filter((_, i) => i !== index));
  }

  async function recheck() {
    setRechecking(true);
    const result = await importValidateAction(batchId, rows);
    setRechecking(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    setRows(result.data?.rows ?? rows);
  }

  return (
    <section aria-labelledby="import-review-heading" className="card-base p-6 space-y-5">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div>
          <h2 className="subsection-title text-foreground" id="import-review-heading">
            Review &amp; edit
          </h2>
          <p className="text-sm text-muted-foreground mt-1">
            Fix any invalid or duplicate rows, then configure courses, mentors, and field locks below.
          </p>
        </div>
        <Button disabled={rechecking} size="sm" variant="outline" onClick={recheck}>
          <RefreshCw aria-hidden className={`mr-1.5 h-4 w-4 ${rechecking ? "animate-spin" : ""}`} />
          {rechecking ? "Checking…" : "Re-check rows"}
        </Button>
      </div>

      <div className="flex flex-wrap gap-2 text-sm">
        <span className="text-muted-foreground">{rows.length} total</span>
        {(Object.keys(STATUS_LABEL) as ImportRowStatus[]).map((s) =>
          counts[s] ? (
            <Badge key={s} variant={STATUS_VARIANT[s]}>
              {counts[s]} {STATUS_LABEL[s]}
            </Badge>
          ) : null,
        )}
      </div>

      <div className="table-responsive">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs text-muted-foreground">
              <th className="pb-2 pr-3 font-medium">Full Name</th>
              <th className="pb-2 pr-3 font-medium">Email</th>
              <th className="pb-2 pr-3 font-medium">Roll Number</th>
              <th className="pb-2 pr-3 font-medium">Status</th>
              <th className="pb-2 font-medium sr-only">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {rows.map((row, i) => (
              <tr key={`${row.email}-${i}`}>
                <td className="py-2.5 pr-3 font-medium">{row.full_name}</td>
                <td className="py-2.5 pr-3 text-muted-foreground">{row.email}</td>
                <td className="py-2.5 pr-3 text-muted-foreground">{row.roll_number || "—"}</td>
                <td className="py-2.5 pr-3">
                  <Badge variant={STATUS_VARIANT[row.status]}>{STATUS_LABEL[row.status]}</Badge>
                  {row.errors && row.errors.length > 0 && (
                    <p className="text-xs text-destructive mt-1">{row.errors.join(" ")}</p>
                  )}
                </td>
                <td className="py-2.5 text-right whitespace-nowrap">
                  <Button
                    aria-label={`Edit row ${i + 1}`}
                    className="touch-target"
                    size="icon"
                    variant="ghost"
                    onClick={() => setEditingIndex(i)}
                  >
                    <Pencil aria-hidden className="h-4 w-4" />
                  </Button>
                  <Button
                    aria-label={`Remove row ${i + 1}`}
                    className="touch-target"
                    size="icon"
                    variant="ghost"
                    onClick={() => removeRow(i)}
                  >
                    <Trash2 aria-hidden className="h-4 w-4" />
                  </Button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {editingIndex !== null && (
        <EditRowDialog
          open
          row={rows[editingIndex]}
          onOpenChange={(open) => {
            if (!open) setEditingIndex(null);
          }}
          onSave={(updated) => {
            updateRow(editingIndex, updated);
            setEditingIndex(null);
          }}
        />
      )}

      <ImportConfigPanel
        batchId={batchId}
        blockingCount={blockingCount}
        courses={courses}
        orgMembers={orgMembers}
        rows={rows}
        onConfirmed={onConfirmed}
      />
    </section>
  );
}
