"use client";

import * as React from "react";
import { parseAsStringEnum, useQueryState } from "nuqs";
import { UploadStep } from "@/app/(app)/batches/[id]/import/upload-step";
import { ReviewStep } from "@/app/(app)/batches/[id]/import/review-step";
import type { Course } from "@/lib/server/courses";
import type { ImportMemberRow, OrgMemberSummary } from "@/lib/server/batches";

const STEPS = ["upload", "review"] as const;

interface ImportWizardProps {
  batchId: string;
  courses: Course[];
  orgMembers: OrgMemberSummary[];
}

export function ImportWizard({ batchId, courses, orgMembers }: ImportWizardProps) {
  const [step, setStep] = useQueryState("step", parseAsStringEnum([...STEPS]).withDefault("upload"));
  const [rows, setRows] = React.useState<ImportMemberRow[]>([]);

  if (step === "review" && rows.length > 0) {
    return (
      <ReviewStep batchId={batchId} courses={courses} orgMembers={orgMembers} rows={rows} setRows={setRows} />
    );
  }

  return (
    <UploadStep
      batchId={batchId}
      onParsed={(parsed) => {
        setRows(parsed);
        void setStep("review");
      }}
    />
  );
}
