"use client";

import * as React from "react";
import { useRouter, useSelectedLayoutSegment } from "next/navigation";
import { useQueryState } from "nuqs";
import { toast } from "sonner";
import { Users } from "lucide-react";

import { Button } from "@/components/ui/button";
import { assignAssessmentAction } from "@/app/(app)/assessments/actions";
import { selectedBatchesParam } from "@/app/(app)/assessments/[id]/edit/selected-batches-param";

interface AssignActionProps {
  assessmentId: string;
}

// Rendered directly by layout.tsx. Batch selection lives in the "selected"
// URL param (shared with batches-panel.tsx's checkboxes) rather than local
// state, since this button and the checkbox grid are separate components
// with no other way to share selection without portaling into the header.
export function AssignAction({ assessmentId }: AssignActionProps) {
  const router = useRouter();
  const segment = useSelectedLayoutSegment();
  const [selected] = useQueryState("selected", selectedBatchesParam);
  const [busy, setBusy] = React.useState(false);

  if (segment !== "batches") return null;

  const assign = async () => {
    setBusy(true);
    const res = await assignAssessmentAction(assessmentId, "batch", selected);
    setBusy(false);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Assigned to batches.");
    router.refresh();
  };

  return (
    <Button disabled={busy || selected.length === 0} onClick={assign}>
      <Users /> Assign {selected.length > 0 ? `(${selected.length})` : ""}
    </Button>
  );
}
