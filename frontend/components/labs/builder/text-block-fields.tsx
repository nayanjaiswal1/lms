"use client";

import type { Control } from "react-hook-form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSelectField } from "@/components/ui/form-select-field";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import { HINT_LEVELS, TICKET_SEVERITY_OPTIONS } from "@/lib/labs/builder/options";
import type { TextBlockValues } from "@/lib/labs/builder/text-blocks";
import type { TextBlockKind } from "@/lib/labs/builder/types";

interface TextBlockFieldsProps {
  kind: TextBlockKind;
  control: Control<TextBlockValues>;
}

/** The kind-specific fields of the text block form. */
export function TextBlockFields({ kind, control }: TextBlockFieldsProps) {
  switch (kind) {
    case "ticket":
      return (
        <>
          <FormTextareaField
            className="font-mono text-xs"
            control={control}
            description="Markdown. {{symptom.*}}, {{params.*}} and {{captured.trace}} are filled in when the lab is built."
            label="Ticket"
            name="templateMd"
            rows={12}
          />
          <FormSelectField
            control={control}
            label="Severity"
            name="severity"
            options={TICKET_SEVERITY_OPTIONS}
            placeholder="Not set"
          />
          <FormInputField control={control} description="Who is reporting it, e.g. a support lead." label="Reporter persona" name="persona" />
          <FormTextareaField
            control={control}
            description="One per line. Plausible but wrong leads the student may chase."
            label="Red herrings"
            name="redHerrings"
            rows={3}
          />
        </>
      );
    case "hints":
      return (
        <>
          {Array.from({ length: HINT_LEVELS }, (_, i) => (
            <FormTextareaField
              control={control}
              description={i === 0 ? "Start vague and get more specific with each level." : undefined}
              key={i}
              label={`Hint ${i + 1}`}
              name={`hints.${i}`}
              rows={3}
            />
          ))}
        </>
      );
    case "rubric":
      return (
        <>
          <FormTextareaField control={control} description="One per line: what a correct write-up must say." label="Key points" name="keyPoints" rows={5} />
          <FormTextareaField control={control} description="One per line: wrong explanations the review should call out." label="Misconceptions" name="misconceptions" rows={4} />
        </>
      );
    case "preset":
      return (
        <>
          <FormInputField control={control} description="The block key this preset applies to, e.g. dj.perf.n-plus-one-order-list." label="Target block" name="presetTarget" />
          <FormTextareaField className="font-mono text-xs" control={control} description="A JSON object of parameter values." label="Values" name="presetValues" rows={8} />
        </>
      );
  }
}
