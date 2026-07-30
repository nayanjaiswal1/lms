"use client";

import * as React from "react";
import { useRouter, useSelectedLayoutSegment } from "next/navigation";
import { toast } from "sonner";
import { Rocket } from "lucide-react";

import { Button } from "@/components/ui/button";
import { publishAssessmentAction } from "@/app/(app)/assessments/actions";

interface PublishActionProps {
  assessmentId: string;
  isDraft: boolean;
  attachedCount: number;
}

// Rendered directly by layout.tsx (not portaled) so it stays in the
// server-rendered header on first paint — no client-only mount guard needed.
export function PublishAction({ assessmentId, isDraft, attachedCount }: PublishActionProps) {
  const router = useRouter();
  const segment = useSelectedLayoutSegment();
  const [busy, setBusy] = React.useState(false);

  if (!isDraft || segment !== null) return null;

  const publish = async () => {
    setBusy(true);
    const res = await publishAssessmentAction(assessmentId);
    setBusy(false);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Assessment published.");
    router.refresh();
  };

  return (
    <Button disabled={busy || attachedCount === 0} onClick={publish}>
      <Rocket /> Publish
    </Button>
  );
}
