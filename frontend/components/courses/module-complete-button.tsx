"use client";

import { useState } from "react";
import { CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { updateProgressAction } from "@/lib/courses/actions";
import { showRewardToasts } from "@/components/shared/reward-toast";
import { cn } from "@/lib/utils";

interface ModuleCompleteButtonProps {
  moduleId: string;
  initialCompleted: boolean;
  className?: string;
}

export function ModuleCompleteButton({ moduleId, initialCompleted, className }: ModuleCompleteButtonProps) {
  const [completed, setCompleted] = useState(initialCompleted);
  const [pending, setPending] = useState(false);

  async function handleMarkComplete() {
    setPending(true);
    const result = await updateProgressAction({ moduleID: moduleId, status: "completed" });
    setPending(false);
    if (!result.ok) return;
    setCompleted(true);
    if (result.data?.rewards) showRewardToasts(result.data.rewards);
  }

  return (
    <Button
      className={cn("w-full sm:w-fit", className)}
      disabled={completed || pending}
      onClick={handleMarkComplete}
      size="sm"
    >
      {completed ? (
        <>
          <CheckCircle2 aria-hidden className="mr-2 h-4 w-4" />
          Completed
        </>
      ) : pending ? (
        "Marking as complete…"
      ) : (
        "Mark as Complete"
      )}
    </Button>
  );
}
