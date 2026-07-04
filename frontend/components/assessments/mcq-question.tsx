"use client";

import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";
import { PromptRenderer } from "@/components/assessments/prompt-renderer";
import type { StudentMCQContent } from "@/lib/assessments/types";

interface MCQQuestionProps {
  content: StudentMCQContent;
  selected: string[];
  onToggle: (optionId: string, multiple: boolean) => void;
}

// MCQQuestion renders single- or multi-select questions. Prompts containing
// fenced code blocks or inline backticks are rendered via PromptRenderer so
// code-snippet MCQs display styled code instead of raw backtick text.
export function MCQQuestion({ content, selected, onToggle }: MCQQuestionProps) {
  return (
    <div className="flex flex-col gap-6">
      <PromptRenderer text={content.prompt} />

      {content.multiple ? (
        <div className="flex flex-col gap-3">
          <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            Select all that apply
          </p>
          {content.options.map((opt) => (
            <Label
              className={cn(
                "card-base flex cursor-pointer items-start gap-3 p-4 font-normal transition-colors",
                selected.includes(opt.id) && "border-primary bg-primary/5",
              )}
              htmlFor={`opt-${opt.id}`}
              key={opt.id}
            >
              <Checkbox
                checked={selected.includes(opt.id)}
                className="mt-0.5 shrink-0"
                id={`opt-${opt.id}`}
                onCheckedChange={() => onToggle(opt.id, true)}
              />
              <span className="font-mono text-sm leading-relaxed">{opt.text}</span>
            </Label>
          ))}
        </div>
      ) : (
        <RadioGroup
          className="gap-3"
          value={selected[0] ?? ""}
          onValueChange={(v) => onToggle(v, false)}
        >
          {content.options.map((opt) => (
            <Label
              className={cn(
                "card-base flex cursor-pointer items-start gap-3 p-4 font-normal transition-colors",
                selected[0] === opt.id && "border-primary bg-primary/5",
              )}
              htmlFor={`opt-${opt.id}`}
              key={opt.id}
            >
              <RadioGroupItem className="mt-0.5 shrink-0" id={`opt-${opt.id}`} value={opt.id} />
              <span className="font-mono text-sm leading-relaxed">{opt.text}</span>
            </Label>
          ))}
        </RadioGroup>
      )}
    </div>
  );
}
