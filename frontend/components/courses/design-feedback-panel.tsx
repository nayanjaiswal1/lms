"use client";

import { useState, useTransition } from "react";
import { Loader2, Sparkles } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { getDesignFeedbackAction } from "@/lib/design-actions";

interface DesignFeedbackPanelProps {
  moduleId: string;
  attemptId: string;
  initialFeedback?: string;
}

// "Get feedback" action — critiques the current attempt's canvas content
// against the question's guidance. Re-running replaces the stored feedback,
// matching the reference product's re-gradable "Get feedback" button.
export function DesignFeedbackPanel({ moduleId, attemptId, initialFeedback }: DesignFeedbackPanelProps) {
  const [feedback, setFeedback] = useState(initialFeedback ?? null);
  const [isPending, startTransition] = useTransition();

  const handleClick = () => {
    startTransition(async () => {
      const result = await getDesignFeedbackAction(moduleId, attemptId);
      if (result.error || !result.data) {
        toast.error(result.error ?? "Failed to generate feedback.");
        return;
      }
      setFeedback(result.data.feedback);
    });
  };

  return (
    <div className="flex flex-col gap-3">
      <Button className="w-full sm:w-auto" disabled={isPending} onClick={handleClick}>
        {isPending ? (
          <Loader2 aria-hidden className="mr-2 h-4 w-4 animate-spin" />
        ) : (
          <Sparkles aria-hidden className="mr-2 h-4 w-4" />
        )}
        {isPending ? "Reviewing your board…" : feedback ? "Get feedback again" : "Get feedback"}
      </Button>
      {feedback && (
        <div className="ai-surface rounded-lg p-4 text-sm">
          <span className="ai-badge mb-2 inline-flex items-center gap-1">
            <Sparkles aria-hidden className="h-3 w-3" />AI feedback
          </span>
          <p className="whitespace-pre-wrap leading-relaxed">{feedback}</p>
        </div>
      )}
    </div>
  );
}
