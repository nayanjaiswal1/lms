"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toTimeInputValue } from "@/app/(app)/calendar/calendar-math";
import { updateEventAction } from "@/lib/server/calendar";
import { CALENDAR_PRIORITY_OPTIONS } from "@/lib/calendar/types";
import type { CalendarEvent, CalendarEventScope } from "@/lib/calendar/types";

const EditEventSchema = z.object({
  title: z.string().min(1, "Title is required.").max(200),
  date: z.string().min(1, "Date is required."),
  startTime: z.string().min(1, "Start time is required."),
  endTime: z.string().min(1, "End time is required."),
  priority: z.enum(["low", "medium", "high", "urgent"]).optional(),
});
type EditEventFormData = z.infer<typeof EditEventSchema>;

function toDateInputValue(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

function combineDateTime(dateValue: string, timeValue: string): Date {
  const [year, month, day] = dateValue.split("-").map(Number);
  const [hours, minutes] = timeValue.split(":").map(Number);
  return new Date(year, month - 1, day, hours, minutes, 0, 0);
}

interface EditEventFormProps {
  event: CalendarEvent;
  onSaved: (event: CalendarEvent) => void;
  onCancel: () => void;
}

export function EditEventForm({ event, onSaved, onCancel }: EditEventFormProps) {
  const start = new Date(event.starts_at);
  const end = new Date(event.ends_at ?? event.starts_at);
  const form = useForm<EditEventFormData>({
    resolver: zodResolver(EditEventSchema),
    defaultValues: {
      title: event.title,
      date: toDateInputValue(start),
      startTime: toTimeInputValue(start),
      endTime: toTimeInputValue(end),
      priority: event.priority ?? undefined,
    },
  });
  const isTask = event.event_type === "task";

  async function submit(data: EditEventFormData, scope: CalendarEventScope) {
    const newStart = combineDateTime(data.date, data.startTime);
    const newEnd = combineDateTime(data.date, data.endTime);
    if (!(newEnd > newStart)) {
      form.setError("endTime", { message: "End time must be after start time." });
      return;
    }
    const result = await updateEventAction(
      event.id,
      {
        title: data.title,
        starts_at: newStart.toISOString(),
        ends_at: newEnd.toISOString(),
        ...(isTask ? { priority: data.priority } : {}),
      },
      scope,
    );
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Could not save changes.");
      return;
    }
    toast.success("Event updated.");
    onSaved(result.data);
  }

  return (
    <Form {...form}>
      <form className="flex flex-col gap-3">
        <FormField
          control={form.control}
          name="title"
          render={({ field }) => (
            <FormItem>
              <FormLabel className="sr-only">Title</FormLabel>
              <FormControl>
                <Input placeholder="Event title" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <FormField
          control={form.control}
          name="date"
          render={({ field }) => (
            <FormItem>
              <FormLabel className="sr-only">Date</FormLabel>
              <FormControl>
                <Input type="date" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <div className="flex items-start gap-2">
          <FormField
            control={form.control}
            name="startTime"
            render={({ field }) => (
              <FormItem className="flex-1">
                <FormLabel className="sr-only">Start time</FormLabel>
                <FormControl>
                  <Input className="min-w-0" type="time" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
          <span className="shrink-0 pt-2.5 text-sm text-muted-foreground">to</span>
          <FormField
            control={form.control}
            name="endTime"
            render={({ field }) => (
              <FormItem className="flex-1">
                <FormLabel className="sr-only">End time</FormLabel>
                <FormControl>
                  <Input className="min-w-0" type="time" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
        </div>
        {isTask && (
          <FormField
            control={form.control}
            name="priority"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs text-muted-foreground">Priority</FormLabel>
                <Select defaultValue={field.value} onValueChange={field.onChange}>
                  <FormControl>
                    <SelectTrigger aria-label="Task priority">
                      <SelectValue placeholder="No priority" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    {CALENDAR_PRIORITY_OPTIONS.map((opt) => (
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
        )}
        <div className="flex flex-wrap justify-end gap-2">
          <Button disabled={form.formState.isSubmitting} type="button" variant="ghost" onClick={onCancel}>
            Cancel
          </Button>
          {event.recurrence_rule ? (
            <>
              <Button
                disabled={form.formState.isSubmitting}
                size="sm"
                type="button"
                variant="outline"
                onClick={form.handleSubmit((data) => submit(data, "single"))}
              >
                Save this event
              </Button>
              <Button
                disabled={form.formState.isSubmitting}
                size="sm"
                type="button"
                onClick={form.handleSubmit((data) => submit(data, "series"))}
              >
                Save series
              </Button>
            </>
          ) : (
            <Button
              disabled={form.formState.isSubmitting}
              size="sm"
              type="button"
              onClick={form.handleSubmit((data) => submit(data, "single"))}
            >
              Save
            </Button>
          )}
        </div>
      </form>
    </Form>
  );
}
