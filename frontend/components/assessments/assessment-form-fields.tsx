"use client";

import { Controller, type Control } from "react-hook-form";
import type { LucideIcon } from "lucide-react";
import type { AssessmentConfigFormData } from "@/lib/assessments/config-schema";

// Shared visual pieces for the assessment config form — used by both the
// create form and the edit-settings form so the two never drift apart.

export function SectionHeader({ icon: Icon, title, description }: { icon: LucideIcon; title: string; description: string }) {
  return (
    <div className="mb-6 flex items-center gap-3">
      <div className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-lg bg-primary/10">
        <Icon aria-hidden className="h-5 w-5 text-primary" />
      </div>
      <div>
        <h2 className="subsection-title text-foreground">{title}</h2>
        <p className="text-sm text-muted-foreground">{description}</p>
      </div>
    </div>
  );
}

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
        <label className="flex cursor-pointer items-start justify-between gap-4 py-3">
          <span className="space-y-0.5">
            <span className="block text-sm font-medium text-foreground">{label}</span>
            <span className="block text-xs text-muted-foreground">{description}</span>
          </span>
          <span className="relative mt-0.5 inline-flex h-5 w-9 flex-shrink-0">
            <input
              aria-label={label}
              checked={Boolean(field.value)}
              className="peer sr-only"
              type="checkbox"
              onChange={(e) => field.onChange(e.target.checked)}
            />
            <span
              aria-hidden="true"
              className="absolute inset-0 rounded-full border border-border bg-muted transition-colors duration-fast peer-checked:border-primary peer-checked:bg-primary peer-focus-visible:ring-2 peer-focus-visible:ring-primary peer-focus-visible:ring-offset-2"
            />
            <span
              aria-hidden="true"
              className="absolute left-0.5 top-0.5 h-4 w-4 rounded-full bg-background shadow-sm transition-transform duration-fast peer-checked:translate-x-4"
            />
          </span>
        </label>
      )}
    />
  );
}
