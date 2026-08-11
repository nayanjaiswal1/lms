"use client";

import { useState, useTransition } from "react";
import { CheckCircle2, Loader2, XCircle } from "lucide-react";
import { recordCheckAttemptAction } from "@/lib/courses/actions";
import { useModuleGate } from "@/components/courses/module-gate-provider";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import type { KnowledgeCheckQuestion } from "@/lib/courses/markdown";

interface LessonMcqQuestionProps {
  moduleId: string;
  question: KnowledgeCheckQuestion;
}

type Outcome = { kind: "idle" } | { kind: "correct" } | { kind: "incorrect" };

// The mcq-typed sibling of LessonSqlCheckQuestion inside an embedded
// knowledge check. Grading happens server-side (RecordCheckAttempt compares
// the selection against the module's stored answer key) — this component
// never sees or trusts a correctness claim from anywhere but the response.
export function LessonMcqQuestion({ moduleId, question }: LessonMcqQuestionProps) {
  const [selected, setSelected] = useState<string | null>(null);
  const [outcome, setOutcome] = useState<Outcome>({ kind: "idle" });
  const [isPending, startTransition] = useTransition();
  const { markPassed } = useModuleGate();
  const solved = outcome.kind === "correct";

  function submit() {
    if (!selected) return;
    startTransition(async () => {
      const result = await recordCheckAttemptAction({
        moduleID: moduleId,
        questionID: question.id,
        answer: { selected },
      });
      if (result.ok && result.data?.is_correct) {
        setOutcome({ kind: "correct" });
        markPassed(question.id);
      } else {
        setOutcome({ kind: "incorrect" });
      }
    });
  }

  return (
    <div className="flex flex-col gap-3 rounded-lg border border-border bg-card p-4">
      <p className="text-sm font-medium text-foreground">{question.prompt}</p>

      <RadioGroup
        className="flex flex-col gap-2"
        disabled={solved}
        value={selected ?? undefined}
        onValueChange={setSelected}
      >
        {question.options?.map((option) => (
          <label
            className={cn(
              "flex cursor-pointer items-center gap-3 rounded-lg border border-border p-3 text-sm transition-colors hover:bg-muted/50",
              selected === option.id && "border-primary bg-primary/5",
            )}
            htmlFor={`${question.id}-${option.id}`}
            key={option.id}
          >
            <RadioGroupItem id={`${question.id}-${option.id}`} value={option.id} />
            <span className="font-normal text-foreground">{option.text}</span>
          </label>
        ))}
      </RadioGroup>

      <Button className="w-fit" disabled={!selected || isPending || solved} size="sm" onClick={submit}>
        {solved ? (
          <>
            <CheckCircle2 aria-hidden className="mr-1 h-3.5 w-3.5" />
            Correct
          </>
        ) : isPending ? (
          <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />
        ) : (
          "Submit"
        )}
      </Button>

      {outcome.kind === "incorrect" && (
        <p className="flex items-center gap-1.5 text-xs text-destructive">
          <XCircle aria-hidden className="h-3.5 w-3.5" />
          Not quite — try again.
        </p>
      )}
      {outcome.kind === "correct" && question.explanation && (
        <p className="text-xs text-muted-foreground">{question.explanation}</p>
      )}
    </div>
  );
}
