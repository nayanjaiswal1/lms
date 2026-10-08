"use client";

import { Controller, type Control } from "react-hook-form";
import { Switch } from "@/components/ui/switch";
import type { AssessmentConfigFormData } from "@/lib/assessments/config-schema";

// Shared visual pieces for the assessment config form — used by both the
// create form and the edit-settings form so the two never drift apart.

export function ToggleRow({
  control,
  name,
  label,
  description,
}: {
  control: Control<AssessmentConfigFormData>;
  name: keyof AssessmentConfigFormData;
  label: string;
  description: string;
}) {
  return (
    <Controller
      control={control}
      name={name}
      render={({ field }) => (
        <label className="flex cursor-pointer items-start justify-between gap-4 py-3" htmlFor={`toggle-${name}`}>
          <span className="space-y-0.5">
            <span className="block text-sm font-medium text-foreground">{label}</span>
            <span className="block text-xs text-muted-foreground">{description}</span>
          </span>
          <Switch
            aria-label={label}
            checked={Boolean(field.value)}
            className="mt-0.5 h-5 w-9 border-border data-[state=checked]:border-primary focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
            id={`toggle-${name}`}
            thumbClassName="h-4 w-4 shadow-card data-[state=checked]:translate-x-4 data-[state=unchecked]:translate-x-0.5"
            onCheckedChange={field.onChange}
          />
        </label>
      )}
    />
  );
}
