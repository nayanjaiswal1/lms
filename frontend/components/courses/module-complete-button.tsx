"use client";

import { useState } from "react";
import { CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { updateProgressAction } from "@/lib/courses/actions";
import { showRewardToasts } from "@/components/shared/reward-toast";
import { useModuleGate } from "@/components/courses/module-gate-provider";
import { cn } from "@/lib/utils";

interface ModuleCompleteButtonProps {
  moduleId: string;
  initialCompleted: boolean;
  className?: string;
}

export function ModuleCompleteButton({ moduleId, initialCompleted, className }: ModuleCompleteButtonProps) {
  const [completed, setCompleted] = useState(initialCompleted);
  const [pending, setPending] = useState(false);
  const { requiredIds, passedIds, labRequired, labCompleted, reflectionRequired, reflectionCompleted } = useModuleGate();
  const checkPending = requiredIds.some((id) => !passedIds.has(id));
  const labPending = labRequired && !labCompleted;
  const reflectionPending = reflectionRequired && !reflectionCompleted;
  const locked = !completed && (checkPending || labPending || reflectionPending);
  const missing = [
    checkPending && "answer the knowledge check",
    labPending && "complete the attached lab",
    reflectionPending && "save your reflection",
  ].filter((x): x is string => Boolean(x));
  const lockedReason = missing.length > 0 ? `Please ${missing.join(", ")} first.` : undefined;

  async function handleToggle() {
    const nextStatus = completed ? "in_progress" : "completed";
    setPending(true);
    const result = await updateProgressAction({ moduleID: moduleId, status: nextStatus });
    setPending(false);
    if (!result.ok) return;
    setCompleted(!completed);
    if (nextStatus === "completed" && result.data?.rewards) showRewardToasts(result.data.rewards);
  }

  return (
    <Button
      className={cn("w-full sm:w-fit", className)}
      disabled={pending || locked}
      size="sm"
      title={locked ? lockedReason : undefined}
      variant={completed ? "outline" : "default"}
      onClick={handleToggle}
    >
      {pending ? (
        completed ? "Marking as incomplete…" : "Marking as complete…"
      ) : completed ? (
        <>
          <CheckCircle2 aria-hidden className="mr-2 h-4 w-4" />
          Completed
        </>
      ) : locked ? (
        checkPending
          ? "Answer the knowledge check first"
          : labPending
            ? "Complete the lab first"
            : "Save your reflection first"
      ) : (
        "Mark as Complete"
      )}
    </Button>
  );
}
