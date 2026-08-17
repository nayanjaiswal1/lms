"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { X } from "lucide-react";
import { useForm, type Control } from "react-hook-form";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSliderField } from "@/components/ui/form-slider-field";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import { fieldsForHabit, HABIT_TYPE_ICON, schemaForFields, type FieldDef } from "@/lib/habits/type-schemas";
import type { Habit } from "@/lib/server/habits";

interface HabitEntryFormProps {
  habit: Habit;
  period: string;
  initialMetadata: Record<string, unknown>;
  onClose: () => void;
  onSave: (metadata: Record<string, unknown>) => Promise<boolean>;
}

// Dynamic entry form rendered below the grid when a typed habit's row is
// clicked — the mockup's "Dynamic fields based on habit type" panel. Field
// list and validation both come from lib/habits/type-schemas.ts so a new
// habit type only needs to be added there.
export function HabitEntryForm({ habit, period, initialMetadata, onClose, onSave }: HabitEntryFormProps) {
  const fields = fieldsForHabit(habit);
  const Schema = schemaForFields(fields);
  const Icon = HABIT_TYPE_ICON[habit.type];

  const form = useForm<Record<string, unknown>>({
    resolver: zodResolver(Schema),
    defaultValues: defaultsFor(fields, initialMetadata),
  });

  async function onSubmit(data: Record<string, unknown>) {
    const cleaned = Object.fromEntries(Object.entries(data).filter(([, v]) => v !== undefined && v !== ""));
    const ok = await onSave(cleaned);
    if (ok) onClose();
  }

  return (
    <section className="journal-input-panel rounded-lg border border-dashed border-border bg-muted/30 p-4">
      <div className="mb-4 flex items-start justify-between">
        <div className="flex items-center gap-2">
          <Icon aria-hidden className="size-4 text-primary" />
          <h3 className="habits-journal-headline text-sm font-semibold uppercase tracking-widest text-primary">
            {habit.name}
          </h3>
          <span className="text-xs text-muted-foreground">{period}</span>
        </div>
        <Button aria-label="Close" className="touch-target" size="icon" variant="ghost" onClick={onClose}>
          <X aria-hidden className="size-4" />
        </Button>
      </div>
      <Form {...form}>
        <form className="grid grid-cols-1 gap-4 sm:grid-cols-2" onSubmit={form.handleSubmit(onSubmit)}>
          {fields.map((f) => (
            <div className={f.kind === "textarea" ? "sm:col-span-2" : undefined} key={f.key}>
              {renderField(f, form.control)}
            </div>
          ))}
          <div className="sm:col-span-2">
            <Button disabled={form.formState.isSubmitting} size="sm" type="submit">
              Save
            </Button>
          </div>
        </form>
      </Form>
    </section>
  );
}

function defaultsFor(fields: FieldDef[], metadata: Record<string, unknown>): Record<string, unknown> {
  const defaults: Record<string, unknown> = {};
  for (const f of fields) {
    const value = metadata[f.key];
    defaults[f.key] = f.kind === "slider" ? (typeof value === "number" ? value : 0) : (value ?? "");
  }
  return defaults;
}

function renderField(field: FieldDef, control: Control<Record<string, unknown>>) {
  switch (field.kind) {
    case "textarea":
      return <FormTextareaField control={control} label={field.label} name={field.key} placeholder={field.placeholder} />;
    case "slider":
      return <FormSliderField control={control} label={field.label} name={field.key} />;
    case "time":
      return <FormInputField className="sm:w-36" control={control} label={field.label} name={field.key} type="time" />;
    case "number":
      return <FormInputField control={control} label={field.label} name={field.key} placeholder={field.placeholder} type="number" />;
    default:
      return <FormInputField control={control} label={field.label} name={field.key} placeholder={field.placeholder} type="text" />;
  }
}
