"use client";

import { CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

interface AnonModuleCompleteButtonProps {
  completed: boolean;
  onToggle: () => void;
  className?: string;
  /** Reflection-required gate (courses.disable_reflection) — the one gate anonymous access needs, see anon-lesson-page.tsx. */
  locked?: boolean;
}

// Anonymous counterpart to module-complete-button.tsx — no server round trip
// (the caller, anon-lesson-page.tsx, owns the localStorage write) and no
// knowledge-check/lab gate, since anonymous access is only offered for
// notes/system_design modules, which never carry either. Reflection is the
// one gate anonymous visitors do have (AnonLessonReflection), so `locked`
// covers just that.
export function AnonModuleCompleteButton({ completed, onToggle, className, locked = false }: AnonModuleCompleteButtonProps) {
  return (
    <Button
      className={cn("w-full sm:w-fit", className)}
      disabled={!completed && locked}
      size="sm"
      title={!completed && locked ? "Save your reflection first." : undefined}
      variant={completed ? "outline" : "default"}
      onClick={onToggle}
    >
      {completed ? (
        <>
          <CheckCircle2 aria-hidden className="mr-2 h-4 w-4" />
          Completed
        </>
      ) : locked ? (
        "Save your reflection first"
      ) : (
        "Mark as Complete"
      )}
    </Button>
  );
}
