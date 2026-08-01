"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSwitchField } from "@/components/ui/form-switch-field";
import { updateBookingConfigAction, type BookingConfig } from "@/lib/server/sessions";

const Schema = z.object({
  enabled: z.boolean(),
  require_credits: z.boolean(),
  cancel_cutoff_hours: z.coerce.number().int().min(0).max(336),
  min_notice_hours: z.coerce.number().int().min(0).max(336),
  booking_horizon_days: z.coerce.number().int().min(1).max(365),
  max_upcoming_per_student: z.coerce.number().int().min(1).max(100),
  default_duration_minutes: z.coerce.number().int().min(5).max(480),
});
type FormInput = z.input<typeof Schema>;
type FormData = z.output<typeof Schema>;

interface BookingPolicyFormProps {
  config: BookingConfig;
}

export function BookingPolicyForm({ config }: BookingPolicyFormProps) {
  const form = useForm<FormInput, unknown, FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      enabled: config.enabled,
      require_credits: config.require_credits,
      cancel_cutoff_hours: config.cancel_cutoff_hours,
      min_notice_hours: config.min_notice_hours,
      booking_horizon_days: config.booking_horizon_days,
      max_upcoming_per_student: config.max_upcoming_per_student,
      default_duration_minutes: config.default_duration_minutes,
    },
  });

  const onSubmit = async (data: FormData) => {
    const res = await updateBookingConfigAction(data);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Booking policy saved.");
  };

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormSwitchField
          control={form.control}
          description="Turn session booking off for the whole organization."
          label="Enable session booking"
          name="enabled"
        />
        <FormSwitchField
          control={form.control}
          description="Students spend a credit per booking. Turning this on with no packs published leaves students unable to book — publish at least one pack first."
          label="Require credits to book"
          name="require_credits"
        />
        <div className="grid gap-4 sm:grid-cols-2">
          <FormInputField
            control={form.control}
            description="Cancel earlier than this to get the credit back."
            label="Cancellation cutoff (hours)"
            name="cancel_cutoff_hours"
            type="number"
          />
          <FormInputField
            control={form.control}
            description="A student can't book a session starting sooner than this."
            label="Minimum notice (hours)"
            name="min_notice_hours"
            type="number"
          />
          <FormInputField
            control={form.control}
            description="How far into the future a student is allowed to book."
            label="Booking horizon (days)"
            name="booking_horizon_days"
            type="number"
          />
          <FormInputField
            control={form.control}
            description="Caps how many upcoming sessions one student can have booked at once."
            label="Max upcoming sessions per student"
            name="max_upcoming_per_student"
            type="number"
          />
          <FormInputField
            control={form.control}
            description="Pre-filled length when a mentor or student books a new session."
            label="Default session length (minutes)"
            name="default_duration_minutes"
            type="number"
          />
        </div>
        <div className="flex justify-end">
          <Button disabled={form.formState.isSubmitting} type="submit">
            {form.formState.isSubmitting ? "Saving…" : "Save policy"}
          </Button>
        </div>
      </form>
    </Form>
  );
}
