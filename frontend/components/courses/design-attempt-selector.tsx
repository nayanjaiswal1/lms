"use client";

import { useTransition } from "react";
import { Loader2, Plus } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { createDesignAttemptAction } from "@/lib/design-actions";
import type { DesignAttemptSummary } from "@/lib/design";

interface DesignAttemptSelectorProps {
  moduleId: string;
  attempts: DesignAttemptSummary[];
  selectedAttemptId: string | undefined;
  onSelect: (attemptId: string) => void;
  onCreated: (attempt: DesignAttemptSummary) => void;
}

// The reference product's colored-dot "attempt" row — restart a question
// from a blank canvas without losing earlier tries.
export function DesignAttemptSelector({ moduleId, attempts, selectedAttemptId, onSelect, onCreated }: DesignAttemptSelectorProps) {
  const [isCreating, startCreating] = useTransition();

  const handleNewAttempt = () => {
    startCreating(async () => {
      const result = await createDesignAttemptAction(moduleId);
      if (result.error || !result.data) {
        toast.error(result.error ?? "Failed to start a new attempt.");
        return;
      }
      onCreated({
        id: result.data.id,
        attempt_number: result.data.attempt_number,
        has_feedback: false,
        created_at: result.data.created_at,
        updated_at: result.data.updated_at,
      });
    });
  };

  return (
    <div className="flex items-center gap-1.5">
      {attempts.map((a) => (
        <button
          aria-current={a.id === selectedAttemptId}
          aria-label={`Attempt ${a.attempt_number}${a.has_feedback ? " (has feedback)" : ""}`}
          className={cn(
            "touch-target flex h-8 w-8 items-center justify-center rounded-full border text-xs font-semibold transition-colors duration-fast",
            a.id === selectedAttemptId
              ? "border-primary bg-primary text-primary-foreground"
              : "border-border bg-card text-muted-foreground hover:bg-muted",
          )}
          key={a.id}
          type="button"
          onClick={() => onSelect(a.id)}
        >
          {a.attempt_number}
        </button>
      ))}
      <Button
        aria-label="Start a new attempt"
        className="touch-target"
        disabled={isCreating}
        size="icon"
        variant="outline"
        onClick={handleNewAttempt}
      >
        {isCreating ? <Loader2 aria-hidden className="h-4 w-4 animate-spin" /> : <Plus aria-hidden className="h-4 w-4" />}
      </Button>
    </div>
  );
}
