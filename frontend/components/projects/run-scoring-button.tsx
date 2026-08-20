"use client";

import * as React from "react";
import { Sparkles } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { requestScoringAction } from "@/app/(app)/projects/actions";

interface RunScoringButtonProps {
  requirementId: string;
  unscoredCount: number;
}

export function RunScoringButton({ requirementId, unscoredCount }: RunScoringButtonProps) {
  const [pending, setPending] = React.useState(false);
  const router = useRouter();

  async function handleRun() {
    setPending(true);
    const result = await requestScoringAction(requirementId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("AI scoring started — refresh in a moment to see rankings.");
    router.refresh();
  }

  if (unscoredCount === 0) return null;

  return (
    <Button disabled={pending} size="sm" variant="outline" onClick={handleRun}>
      <Sparkles aria-hidden className="mr-1.5 h-3.5 w-3.5 text-ai" />
      {pending ? "Starting…" : `Rank ${unscoredCount} with AI`}
    </Button>
  );
}
