"use client";

import { useState } from "react";
import { zodResolver } from "@hookform/resolvers/zod";
import { CalendarDays, CalendarRange, Plus, Sun, Trash2 } from "lucide-react";
import { useFieldArray, useForm } from "react-hook-form";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSelectField } from "@/components/ui/form-select-field";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { WEEKDAY_OPTIONS } from "@/lib/constants";
import { CUSTOM_FIELD_KIND_OPTIONS, HABIT_TYPE_OPTIONS, slugifyFieldKey } from "@/lib/habits/type-schemas";
import type { CustomField, HabitCadence, HabitType } from "@/lib/server/habits";
import { cn } from "@/lib/utils";

const CADENCE_OPTIONS: { value: HabitCadence; label: string; icon: typeof Sun }[] = [
  { value: "daily", label: "Daily", icon: Sun },
  { value: "weekly", label: "Weekly", icon: CalendarDays },
  { value: "monthly", label: "Monthly", icon: CalendarRange },
];

const WEEKLY_MODE_OPTIONS = [
  { value: "count", label: "Any N times" },
  { value: "days", label: "Specific days" },
] as const;

const CustomFieldSchema = z.object({
  label: z.string().trim().min(1, "Required").max(60, "Must not exceed 60 characters"),
  kind: z.enum(["text", "number", "textarea", "time", "slider"]),
});

const Schema = z
  .object({
    name: z.string().trim().min(1, "Required").max(60, "Must not exceed 60 characters"),
    cadence: z.enum(["daily", "weekly", "monthly"]),
    weeklyMode: z.enum(["count", "days"]),
    targetCount: z.coerce.number().int().min(1).max(7),
    weekdays: z.array(z.number().int().min(0).max(6)),
    type: z.enum(["generic", "gym", "sleep", "reading", "custom"]),
    customFields: z.array(CustomFieldSchema),
  })
  .refine((data) => data.cadence !== "weekly" || data.weeklyMode !== "days" || data.weekdays.length > 0, {
    message: "Pick at least one day",
    path: ["weekdays"],
  })
  .refine((data) => data.type !== "custom" || data.customFields.length > 0, {
    message: "Add at least one field",
    path: ["customFields"],
  })
  .refine(
    (data) => {
      if (data.type !== "custom") return true;
      const keys = data.customFields.map((f) => slugifyFieldKey(f.label));
      return new Set(keys).size === keys.length && keys.every((k) => k.length > 0);
    },
    { message: "Field names must be unique", path: ["customFields"] },
  );
type FormInput = z.input<typeof Schema>;
type FormData = z.output<typeof Schema>;

const DEFAULT_VALUES: FormInput = {
  name: "",
  cadence: "daily",
  weeklyMode: "count",
  targetCount: 2,
  weekdays: [],
  type: "generic",
  customFields: [],
};

interface AddHabitInlineProps {
  onAdd: (
    name: string,
    cadence: HabitCadence,
    targetCount?: number,
    weekdays?: number[],
    type?: HabitType,
    customFields?: CustomField[],
  ) => Promise<void>;
}

export function AddHabitInline({ onAdd }: AddHabitInlineProps) {
  const [open, setOpen] = useState(false);
  const form = useForm<FormInput, unknown, FormData>({
    resolver: zodResolver(Schema),
    defaultValues: DEFAULT_VALUES,
  });
  const cadence = form.watch("cadence");
  const weeklyMode = form.watch("weeklyMode");
  const weekdays = form.watch("weekdays");
  const type = form.watch("type");
  const customFieldsArray = useFieldArray({ control: form.control, name: "customFields" });

  function handleOpenChange(next: boolean) {
    setOpen(next);
    if (!next) form.reset(DEFAULT_VALUES);
  }

  async function onSubmit(data: FormData) {
    const customFields: CustomField[] | undefined =
      data.type === "custom"
        ? data.customFields.map((f) => ({ key: slugifyFieldKey(f.label), label: f.label, kind: f.kind }))
        : undefined;
    if (data.cadence === "weekly" && data.weeklyMode === "days") {
      await onAdd(data.name, data.cadence, 1, data.weekdays, data.type, customFields);
    } else if (data.cadence === "weekly") {
      await onAdd(data.name, data.cadence, data.targetCount, [], data.type, customFields);
    } else {
      await onAdd(data.name, data.cadence, undefined, undefined, data.type, customFields);
    }
    form.reset(DEFAULT_VALUES);
    setOpen(false);
  }

  function toggleWeekday(day: number) {
    const next = weekdays.includes(day) ? weekdays.filter((d) => d !== day) : [...weekdays, day];
    form.setValue("weekdays", next, { shouldValidate: true });
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>
        <Button className="touch-target gap-1.5" type="button" variant="default">
          <Plus aria-hidden className="size-4" />
          Add habit
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Add habit</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="flex flex-col gap-5" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField
              control={form.control}
              label="Habit name"
              name="name"
              placeholder="e.g. Exercise for 20 minutes"
            />

            <div className="flex flex-col gap-1.5">
              <span className="text-xs font-medium text-muted-foreground">Cadence</span>
              <div className="flex gap-1 rounded-md border border-border p-1">
                {CADENCE_OPTIONS.map((option) => (
                  <Button
                    aria-pressed={cadence === option.value}
                    className={cn("touch-target flex-1 gap-1.5 px-2.5", cadence === option.value && "bg-accent")}
                    key={option.value}
                    size="sm"
                    type="button"
                    variant="ghost"
                    onClick={() => form.setValue("cadence", option.value)}
                  >
                    <option.icon
                      aria-hidden
                      className={cn("size-4", cadence === option.value ? "text-primary" : "text-muted-foreground")}
                    />
                    <span
                      className={cn("text-xs", cadence === option.value ? "text-primary" : "text-muted-foreground")}
                    >
                      {option.label}
                    </span>
                  </Button>
                ))}
              </div>
            </div>

            {cadence === "weekly" && (
              <div className="flex flex-col gap-3 rounded-md border border-border p-3">
                <div className="flex gap-1">
                  {WEEKLY_MODE_OPTIONS.map((option) => (
                    <Button
                      aria-pressed={weeklyMode === option.value}
                      className={cn("touch-target px-2.5 text-xs", weeklyMode === option.value && "bg-accent")}
                      key={option.value}
                      size="sm"
                      type="button"
                      variant="ghost"
                      onClick={() => form.setValue("weeklyMode", option.value)}
                    >
                      {option.label}
                    </Button>
                  ))}
                </div>

                {weeklyMode === "count" ? (
                  <div className="w-full sm:w-32">
                    <FormInputField
                      control={form.control}
                      label="Times / week"
                      max={7}
                      min={1}
                      name="targetCount"
                      type="number"
                    />
                  </div>
                ) : (
                  <div className="flex flex-col gap-1">
                    <div className="flex flex-wrap gap-1">
                      {WEEKDAY_OPTIONS.map((day) => (
                        <Button
                          aria-label={day.label}
                          aria-pressed={weekdays.includes(day.value)}
                          className={cn(
                            "touch-target px-2.5 text-xs",
                            weekdays.includes(day.value) && "bg-accent text-primary",
                          )}
                          key={day.value}
                          size="sm"
                          type="button"
                          variant="ghost"
                          onClick={() => toggleWeekday(day.value)}
                        >
                          {day.label.slice(0, 2)}
                        </Button>
                      ))}
                    </div>
                    {form.formState.errors.weekdays && (
                      <span className="text-xs text-destructive">{form.formState.errors.weekdays.message}</span>
                    )}
                  </div>
                )}
              </div>
            )}

            <div className="flex flex-col gap-1.5">
              <span className="text-xs font-medium text-muted-foreground">Type</span>
              <Select
                value={type}
                onValueChange={(value: HabitType) => {
                  form.setValue("type", value, { shouldValidate: true });
                  if (value !== "custom") form.setValue("customFields", []);
                  else if (customFieldsArray.fields.length === 0) customFieldsArray.append({ label: "", kind: "text" });
                }}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {HABIT_TYPE_OPTIONS.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {type === "custom" && (
              <div className="flex flex-col gap-2 rounded-md border border-border p-3">
                {customFieldsArray.fields.map((field, index) => (
                  <div className="flex items-start gap-1.5" key={field.id}>
                    <div className="flex-1">
                      <FormInputField
                        control={form.control}
                        label={`Field ${index + 1}`}
                        name={`customFields.${index}.label`}
                        placeholder="e.g. Mood"
                      />
                    </div>
                    <div className="w-32">
                      <FormSelectField
                        control={form.control}
                        label="Kind"
                        name={`customFields.${index}.kind`}
                        options={CUSTOM_FIELD_KIND_OPTIONS}
                      />
                    </div>
                    <Button
                      aria-label={`Remove field ${index + 1}`}
                      className="touch-target mt-6"
                      size="icon"
                      type="button"
                      variant="ghost"
                      onClick={() => customFieldsArray.remove(index)}
                    >
                      <Trash2 aria-hidden className="size-4 text-destructive" />
                    </Button>
                  </div>
                ))}
                {form.formState.errors.customFields?.message && (
                  <span className="text-xs text-destructive">{form.formState.errors.customFields.message}</span>
                )}
                <Button
                  className="touch-target w-fit gap-1.5"
                  size="sm"
                  type="button"
                  variant="outline"
                  onClick={() => customFieldsArray.append({ label: "", kind: "text" })}
                >
                  <Plus aria-hidden className="size-4" />
                  Add field
                </Button>
              </div>
            )}

            <DialogFooter>
              <DialogClose asChild>
                <Button className="touch-target" type="button" variant="ghost">
                  Cancel
                </Button>
              </DialogClose>
              <Button className="touch-target" disabled={form.formState.isSubmitting} type="submit">
                Add habit
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
