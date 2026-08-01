"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormSelectField } from "@/components/ui/form-select-field";
import { WEEKDAY_OPTIONS } from "@/lib/constants";
import { saveAvailabilityAction, type AvailabilityRule } from "@/lib/server/sessions";
import { AvailabilityDayRow } from "./availability-day-row";

/** "09:30" → 570. Shared with availability-exceptions.tsx for its time-range fields. */
export function timeToMinutes(time: string): number {
  const [h, m] = time.split(":").map(Number);
  return h * 60 + m;
}

/** 570 → "09:30". */
export function minutesToTime(minutes: number): string {
  const h = Math.floor(minutes / 60) % 24;
  const m = minutes % 60;
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
}

const DEFAULT_START_MINUTE = 9 * 60;
const DEFAULT_END_MINUTE = 17 * 60;
const DEFAULT_SLOT_MINUTES = "30";

const DayRuleSchema = z.object({
  weekday: z.number().min(0).max(6),
  active: z.boolean(),
  start_time: z.string().min(1, "Required."),
  end_time: z.string().min(1, "Required."),
  slot_minutes: z.string().min(1),
});

const AvailabilityFormSchema = z
  .object({
    timezone: z.string().min(1, "Choose a timezone."),
    rules: z.array(DayRuleSchema).length(7),
  })
  .superRefine((data, ctx) => {
    data.rules.forEach((row, index) => {
      if (!row.active) return;
      const start = timeToMinutes(row.start_time);
      const end = timeToMinutes(row.end_time);
      if (end <= start) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "End time must be after start time.",
          path: ["rules", index, "end_time"],
        });
        return;
      }
      if (end - start < Number(row.slot_minutes)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "This window is shorter than the slot length — widen it or pick a shorter slot.",
          path: ["rules", index, "slot_minutes"],
        });
      }
    });
  });

export type AvailabilityFormData = z.infer<typeof AvailabilityFormSchema>;

// Platform enumeration, not app config — rung 4 of the ladder. Falls back to
// just the viewer's own zone on runtimes without Intl.supportedValuesOf.
const TIMEZONE_OPTIONS = (
  typeof Intl.supportedValuesOf === "function"
    ? Intl.supportedValuesOf("timeZone")
    : [Intl.DateTimeFormat().resolvedOptions().timeZone]
).map((tz) => ({ label: tz, value: tz }));

function buildDefaultValues(rules: AvailabilityRule[]): AvailabilityFormData {
  const byWeekday = new Map(rules.map((r) => [r.weekday, r]));
  const timezone = rules[0]?.timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone;
  return {
    timezone,
    rules: WEEKDAY_OPTIONS.map(({ value: weekday }) => {
      const existing = byWeekday.get(weekday);
      return {
        weekday,
        active: existing?.active ?? false,
        start_time: minutesToTime(existing?.start_minute ?? DEFAULT_START_MINUTE),
        end_time: minutesToTime(existing?.end_minute ?? DEFAULT_END_MINUTE),
        slot_minutes: String(existing?.slot_minutes ?? DEFAULT_SLOT_MINUTES),
      };
    }),
  };
}

interface WeeklyAvailabilityEditorProps {
  rules: AvailabilityRule[];
}

/** The whole week is replaced atomically on save — there is no per-row diff. */
export function WeeklyAvailabilityEditor({ rules }: WeeklyAvailabilityEditorProps) {
  const form = useForm<AvailabilityFormData>({
    resolver: zodResolver(AvailabilityFormSchema),
    defaultValues: buildDefaultValues(rules),
  });

  const onSubmit = async (data: AvailabilityFormData) => {
    const payload = data.rules.map((row) => ({
      weekday: row.weekday,
      active: row.active,
      start_minute: timeToMinutes(row.start_time),
      end_minute: timeToMinutes(row.end_time),
      slot_minutes: Number(row.slot_minutes),
      timezone: data.timezone,
    }));
    const res = await saveAvailabilityAction(payload);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Availability saved.");
  };

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <div className="w-full sm:max-w-xs">
          <FormSelectField control={form.control} label="Timezone" name="timezone" options={TIMEZONE_OPTIONS} />
        </div>
        <div className="flex flex-col gap-3">
          {WEEKDAY_OPTIONS.map((day, index) => (
            <AvailabilityDayRow control={form.control} index={index} key={day.value} label={day.label} />
          ))}
        </div>
        <div className="flex justify-end">
          <Button disabled={form.formState.isSubmitting} type="submit">
            {form.formState.isSubmitting ? "Saving…" : "Save availability"}
          </Button>
        </div>
      </form>
    </Form>
  );
}
