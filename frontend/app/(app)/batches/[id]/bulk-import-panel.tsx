"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { parseAsBoolean, parseAsString, parseAsStringEnum, useQueryState } from "nuqs";

import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { UploadStep } from "@/app/(app)/batches/[id]/import/upload-step";
import { ReviewStep } from "@/app/(app)/batches/[id]/import/review-step";
import { ImportProgressPanel } from "@/app/(app)/batches/[id]/import/import-progress-panel";
import type { ImportJobStatus } from "@/app/(app)/batches/actions";
import type { Course } from "@/lib/server/courses";
import type { ImportMemberRow, OrgMemberSummary } from "@/lib/server/batches";

const STEPS = ["upload", "review", "progress"] as const;

interface BulkImportPanelProps {
  batchId: string;
  courses: Course[];
  orgMembers: OrgMemberSummary[];
  initialJobStatus: ImportJobStatus | null;
}

export function BulkImportPanel({ batchId, courses, orgMembers, initialJobStatus }: BulkImportPanelProps) {
  const [open, setOpen] = useQueryState("bulk-import", parseAsBoolean.withDefault(false));
  const [step, setStep] = useQueryState("step", parseAsStringEnum([...STEPS]).withDefault("upload"));
  const [jobId, setJobId] = useQueryState("job", parseAsString.withDefault(""));
  const [rows, setRows] = React.useState<ImportMemberRow[]>([]);
  const router = useRouter();

  function reset() {
    void setStep("upload");
    void setJobId("");
    setRows([]);
  }

  // Import just started: put its job id in the URL, then force the server
  // component to re-render so it fetches the initial job/report status —
  // nuqs updates the URL shallowly and won't refetch on its own.
  async function goToProgress(newJobId: string) {
    await Promise.all([setJobId(newJobId), setStep("progress")]);
    router.refresh();
  }

  function handleOpenChange(next: boolean) {
    void setOpen(next);
    if (!next) reset();
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="modal-responsive max-h-[90vh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>Bulk import students</DialogTitle>
        </DialogHeader>

        {step === "progress" && jobId && initialJobStatus ? (
          <ImportProgressPanel
            batchId={batchId}
            initialStatus={initialJobStatus}
            jobId={jobId}
            onRunAnother={reset}
          />
        ) : step === "progress" && jobId ? (
          <p className="text-sm text-muted-foreground">Loading import status…</p>
        ) : step === "review" && rows.length > 0 ? (
          <ReviewStep
            batchId={batchId}
            courses={courses}
            orgMembers={orgMembers}
            rows={rows}
            setRows={setRows}
            onConfirmed={(newJobId) => void goToProgress(newJobId)}
          />
        ) : (
          <UploadStep
            batchId={batchId}
            onParsed={(parsed) => {
              setRows(parsed);
              void setStep("review");
            }}
          />
        )}
      </DialogContent>
    </Dialog>
  );
}
