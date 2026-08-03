"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { CalendarDays, CalendarRange, Sun } from "lucide-react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { WEEKDAY_OPTIONS } from "@/lib/constants";
import type { HabitCadence } from "@/lib/server/habits";
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

const Schema = z
  .object({
    name: z.string().trim().min(1, "Required").max(60, "Must not exceed 60 characters"),
    cadence: z.enum(["daily", "weekly", "monthly"]),
    weeklyMode: z.enum(["count", "days"]),
    targetCount: z.coerce.number().int().min(1).max(7),
    weekdays: z.array(z.number().int().min(0).max(6)),
  })
  .refine((data) => data.cadence !== "weekly" || data.weeklyMode !== "days" || data.weekdays.length > 0, {
    message: "Pick at least one day",
    path: ["weekdays"],
  });
type FormInput = z.input<typeof Schema>;
type FormData = z.output<typeof Schema>;

interface AddHabitInlineProps {
  onAdd: (name: string, cadence: HabitCadence, targetCount?: number, weekdays?: number[]) => Promise<void>;
}

export function AddHabitInline({ onAdd }: AddHabitInlineProps) {
  const form = useForm<FormInput, unknown, FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { name: "", cadence: "daily", weeklyMode: "count", targetCount: 2, weekdays: [] },
  });
  const cadence = form.watch("cadence");
  const weeklyMode = form.watch("weeklyMode");
  const weekdays = form.watch("weekdays");

  async function onSubmit(data: FormData) {
    if (data.cadence === "weekly" && data.weeklyMode === "days") {
      await onAdd(data.name, data.cadence, 1, data.weekdays);
    } else if (data.cadence === "weekly") {
      await onAdd(data.name, data.cadence, data.targetCount, []);
    } else {
      await onAdd(data.name, data.cadence);
    }
    form.reset({ name: "", cadence: data.cadence, weeklyMode: "count", targetCount: 2, weekdays: [] });
  }

  function toggleWeekday(day: number) {
    const next = weekdays.includes(day) ? weekdays.filter((d) => d !== day) : [...weekdays, day];
    form.setValue("weekdays", next, { shouldValidate: true });
  }

  return (
    <Form {...form}>
      <form className="flex flex-col gap-2" onSubmit={form.handleSubmit(onSubmit)}>
        <div className="flex flex-col gap-2 sm:flex-row sm:items-start">
          <div className="flex-1">
            <FormInputField control={form.control} label="Habit name" name="name" placeholder="e.g. Exercise for 20 minutes" />
          </div>
          <div className="flex gap-1 rounded-md border border-border p-1 sm:mt-6">
            {CADENCE_OPTIONS.map((option) => (
              <Button
                aria-pressed={cadence === option.value}
                className={cn("touch-target gap-1.5 px-2.5", cadence === option.value && "bg-accent")}
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
                <span className={cn("text-xs", cadence === option.value ? "text-primary" : "text-muted-foreground")}>
                  {option.label}
                </span>
              </Button>
            ))}
          </div>
          <Button className="touch-target sm:mt-6" disabled={form.formState.isSubmitting} size="sm" type="submit">
            Add
          </Button>
        </div>

        {cadence === "weekly" && (
          <div className="flex flex-col gap-2 rounded-md border border-border p-2 sm:flex-row sm:items-center sm:gap-3">
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
              <div className="w-full sm:w-24">
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
                      className={cn("touch-target px-2.5 text-xs", weekdays.includes(day.value) && "bg-accent text-primary")}
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
      </form>
    </Form>
  );
}
