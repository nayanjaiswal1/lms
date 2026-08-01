"use client";

import * as React from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { CalendarPlus } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from "@/components/ui/dialog";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { createEventAction } from "@/lib/server/calendar";

const DURATION_OPTIONS = [
  { label: "30 minutes", value: "30" },
  { label: "45 minutes", value: "45" },
  { label: "60 minutes", value: "60" },
] as const;

const ScheduleSchema = z.object({
  title: z.string().min(2, "Title is required."),
  date: z.string().min(1, "Pick a date."),
  time: z.string().min(1, "Pick a start time."),
  durationMinutes: z.enum(["30", "45", "60"]),
});
type ScheduleFormData = z.infer<typeof ScheduleSchema>;

interface ScheduleSessionButtonProps {
  attendeeId: string;
  triggerLabel?: string;
  size?: "sm" | "default";
  variant?: "outline" | "default";
  className?: string;
}

export function ScheduleSessionButton({
  attendeeId,
  triggerLabel = "Schedule session",
  size = "sm",
  variant = "outline",
  className,
}: ScheduleSessionButtonProps) {
  const [open, setOpen] = React.useState(false);

  const form = useForm<ScheduleFormData>({
    resolver: zodResolver(ScheduleSchema),
    defaultValues: { title: "Mentor session", date: "", time: "", durationMinutes: "30" },
  });

  async function onSubmit(data: ScheduleFormData) {
    const [year, month, day] = data.date.split("-").map(Number);
    const [hour, minute] = data.time.split(":").map(Number);
    const start = new Date(year, month - 1, day, hour, minute);
    const end = new Date(start.getTime() + Number(data.durationMinutes) * 60000);

    const result = await createEventAction({
      event_type: "mentor_session",
      title: data.title,
      starts_at: start.toISOString(),
      ends_at: end.toISOString(),
      visibility: "shared",
      attendee_user_ids: [attendeeId],
    });

    if (!result.ok) {
      toast.error(result.error ?? "Could not schedule the session.");
      return;
    }
    toast.success("Session scheduled.");
    form.reset({ title: "Mentor session", date: "", time: "", durationMinutes: "30" });
    setOpen(false);
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <Button className={className} size={size} variant={variant} onClick={() => setOpen(true)}>
        <CalendarPlus aria-hidden className="mr-1.5 h-4 w-4" />
        {triggerLabel}
      </Button>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Schedule a mentor session</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Title" name="title" />
            <div className="form-row">
              <FormInputField control={form.control} label="Date" name="date" type="date" />
              <FormInputField control={form.control} label="Start time" name="time" type="time" />
            </div>
            <FormField
              control={form.control}
              name="durationMinutes"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Duration</FormLabel>
                  <Select defaultValue={field.value} onValueChange={field.onChange}>
                    <FormControl>
                      <SelectTrigger aria-label="Session duration">
                        <SelectValue />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {DURATION_OPTIONS.map((opt) => (
                        <SelectItem key={opt.value} value={opt.value}>
                          {opt.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Scheduling…" : "Schedule"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
