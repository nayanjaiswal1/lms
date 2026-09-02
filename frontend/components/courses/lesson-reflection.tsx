"use client";

import { useState, useTransition } from "react";
import { CheckCircle2, Loader2 } from "lucide-react";
import { toast } from "sonner";
import { submitReflectionAction } from "@/lib/courses/actions";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { useModuleGate } from "@/components/courses/module-gate-provider";

interface LessonReflectionProps {
  moduleId: string;
  initialResponse: string | null;
}

// Reflection box at the bottom of every notes-type lesson page — below the
// mcq knowledge check, not part of it. Captures what the student says they
// understood, in their own words, per module. This is raw input for a future
// revision-plan / concept-dependency-graph feature (no consumer exists yet,
// so this component only owns capture + persistence, not any graph/plan
// logic). Resubmitting overwrites the previous answer.
//
// Only rendered when the course hasn't set disable_reflection — see
// module-notes.tsx. When shown, saving successfully also reports into
// ModuleGateProvider (markReflectionSaved) so ModuleCompleteButton unlocks
// without a page refresh — this is the "merge reflection into mark complete"
// gate, mirrored on LessonKnowledgeCheck's markPassed.
export function LessonReflection({ moduleId, initialResponse }: LessonReflectionProps) {
  const [response, setResponse] = useState(initialResponse ?? "");
  const [saved, setSaved] = useState(Boolean(initialResponse));
  const [isPending, startTransition] = useTransition();
  const { markReflectionSaved } = useModuleGate();

  function submit() {
    const trimmed = response.trim();
    if (!trimmed) {
      toast.error("Write a few sentences about what you understood first.");
      return;
    }
    startTransition(async () => {
      const result = await submitReflectionAction({ moduleID: moduleId, response: trimmed });
      if (result.ok) {
        setSaved(true);
        markReflectionSaved();
        toast.success("Reflection saved.");
      } else {
        toast.error(result.error ?? "Couldn't save your reflection — try again.");
      }
    });
  }

  return (
    <div className="flex flex-col gap-3 rounded-lg border border-primary/40 bg-card p-4">
      <div>
        <span className="text-xs font-semibold text-primary">Reflect</span>
        <p className="mt-1 text-sm text-muted-foreground">
          In your own words: what did you understand from this lesson? Be specific — this
          feeds directly into your future revision plan.
        </p>
      </div>

      <Textarea
        className="min-h-28"
        onChange={(e) => {
          setResponse(e.target.value);
          setSaved(false);
        }}
        placeholder="I learned that..."
        value={response}
      />

      <Button className="w-fit" disabled={isPending || !response.trim()} onClick={submit} size="sm">
        {isPending ? (
          <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />
        ) : saved ? (
          <>
            <CheckCircle2 aria-hidden className="mr-1 h-3.5 w-3.5" />
            Saved — edit anytime
          </>
        ) : (
          "Save reflection"
        )}
      </Button>
    </div>
  );
}
