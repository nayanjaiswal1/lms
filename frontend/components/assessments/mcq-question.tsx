"use client";

import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";
import type { StudentMCQContent } from "@/lib/assessments/types";

interface MCQQuestionProps {
  content: StudentMCQContent;
  selected: string[];
  onToggle: (optionId: string, multiple: boolean) => void;
}

// Parses a prompt string and renders fenced code blocks (```lang\n…```) as
// <pre><code> and inline `backtick` spans as <code>. Falls back to a plain <p>
// when no code markers are present, so regular MCQ questions are unaffected.
function PromptRenderer({ text }: { text: string }) {
  const segments = text.split(/(```[\w]*\n[\s\S]*?```)/g).filter(Boolean);
  const hasBlocks = segments.some((s) => s.startsWith("```"));

  const nodes = segments.map((seg, i) => {
    const blockMatch = seg.match(/^```(\w*)\n([\s\S]*?)```$/);
    if (blockMatch) {
      const code = blockMatch[2].replace(/\n$/, "");
      return (
        <pre
          key={i}
          className="overflow-x-auto rounded-[--radius-md] border border-border bg-muted p-4 font-mono text-sm leading-relaxed"
        >
          <code>{code}</code>
        </pre>
      );
    }

    const trimmed = seg.replace(/^\n+|\n+$/g, "");
    if (!trimmed) return null;

    // Render inline `code` spans within text segments
    const parts = trimmed.split(/(`[^`\n]+`)/g);
    const inline = parts.map((chunk, j) =>
      chunk.startsWith("`") && chunk.endsWith("`") ? (
        <code key={j} className="rounded bg-muted px-1.5 py-0.5 font-mono text-sm">
          {chunk.slice(1, -1)}
        </code>
      ) : (
        chunk
      ),
    );

    return (
      <p key={i} className="whitespace-pre-wrap text-base leading-relaxed">
        {inline}
      </p>
    );
  });

  return <div className={cn("flex flex-col", hasBlocks ? "gap-3" : "gap-1")}>{nodes}</div>;
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
