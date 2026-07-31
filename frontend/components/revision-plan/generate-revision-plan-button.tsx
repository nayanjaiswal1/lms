"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Sparkles } from "lucide-react";
import { Button } from "@/components/ui/button";
import { generateRevisionPlanAction } from "@/lib/revision-plan/actions";

interface GenerateRevisionPlanButtonProps {
  courseId: string;
  label: string;
}

// Fires the generation request and lets the meta-refresh in
// RevisionPlanCard (matching the roadmap generating-state pattern) pick up
// the transition to "ready" — no client polling or useEffect needed here.
export function GenerateRevisionPlanButton({ courseId, label }: GenerateRevisionPlanButtonProps) {
  const [pending, setPending] = useState(false);

  async function handleClick() {
    setPending(true);
    const result = await generateRevisionPlanAction(courseId);
    setPending(false);
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't start generation — try again.");
      return;
    }
    toast.success("Building your revision plan…");
  }

  return (
    <Button
      className="w-fit border-ai text-ai"
      disabled={pending}
      size="sm"
      variant="outline"
      onClick={handleClick}
    >
      <Sparkles aria-hidden className="mr-1.5 h-3.5 w-3.5" />
      {pending ? "Starting…" : label}
    </Button>
  );
}
