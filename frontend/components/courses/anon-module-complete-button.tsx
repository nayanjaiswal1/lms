"use client";

import { CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

interface AnonModuleCompleteButtonProps {
  completed: boolean;
  onToggle: () => void;
  className?: string;
}

// Anonymous counterpart to module-complete-button.tsx — no server round trip
// (the caller, anon-lesson-page.tsx, owns the localStorage write) and no
// knowledge-check/lab gate, since anonymous access is only offered for
// notes/system_design modules, which never carry either.
export function AnonModuleCompleteButton({ completed, onToggle, className }: AnonModuleCompleteButtonProps) {
  return (
    <Button
      className={cn("w-full sm:w-fit", className)}
      size="sm"
      variant={completed ? "outline" : "default"}
      onClick={onToggle}
    >
      {completed ? (
        <>
          <CheckCircle2 aria-hidden className="mr-2 h-4 w-4" />
          Completed
        </>
      ) : (
        "Mark as Complete"
      )}
    </Button>
  );
}
