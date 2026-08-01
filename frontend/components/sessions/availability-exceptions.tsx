"use client";

import { useState, useTransition } from "react";
import { parseAsBoolean, useQueryState } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Plus, Trash2 } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormSelectField } from "@/components/ui/form-select-field";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Textarea } from "@/components/ui/textarea";
import { SESSION_SLOT_LENGTH_OPTIONS } from "@/lib/constants";
import {
  addAvailabilityExceptionAction,
  deleteAvailabilityExceptionAction,
  type AvailabilityException,
} from "@/lib/server/sessions";
import { minutesToTime, timeToMinutes } from "./weekly-availability-editor";

function formatExceptionRange(exc: AvailabilityException): string {
  if (exc.start_minute === null || exc.end_minute === null) return "All day";
  return `${minutesToTime(exc.start_minute)} – ${minutesToTime(exc.end_minute)}`;
}

function formatExceptionDate(onDate: string): string {
  return new Date(`${onDate}T00:00:00`).toLocaleDateString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

const OverrideSchema = z
  .object({
    on_date: z.string().min(1, "Pick a date."),
    kind: z.enum(["blocked", "open"]),
    start_time: z.string().optional(),
    end_time: z.string().optional(),
    slot_minutes: z.string().min(1),
    note: z.string().max(500).optional(),
  })
  .superRefine((data, ctx) => {
    // An open (extra hours) override always needs a time range — the API
    // rejects an all-day opening. A blocked override may cover the whole day.
    if (data.kind === "open" && (!data.start_time || !data.end_time)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Extra hours need a start and end time — an all-day opening isn't allowed.",
        path: ["start_time"],
      });
      return;
    }
    if (data.start_time && data.end_time && timeToMinutes(data.end_time) <= timeToMinutes(data.start_time)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "End time must be after start time.",
        path: ["end_time"],
      });
    }
  });
type OverrideFormData = z.infer<typeof OverrideSchema>;

function AddOverrideDialog() {
  const [open, setOpen] = useQueryState("add-override", parseAsBoolean.withDefault(false));
  const form = useForm<OverrideFormData>({
    resolver: zodResolver(OverrideSchema),
    defaultValues: { on_date: "", kind: "blocked", start_time: "", end_time: "", slot_minutes: "30", note: "" },
  });
  const kind = form.watch("kind");

  const onSubmit = async (data: OverrideFormData) => {
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    const res = await addAvailabilityExceptionAction({
      on_date: data.on_date,
      is_blocked: data.kind === "blocked",
      start_minute: data.start_time ? timeToMinutes(data.start_time) : null,
      end_minute: data.end_time ? timeToMinutes(data.end_time) : null,
      slot_minutes: Number(data.slot_minutes),
      timezone,
      note: data.note?.trim() || undefined,
    });
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Override added.");
    form.reset();
    void setOpen(false);
  };

  return (
    <Dialog open={open} onOpenChange={(next) => void setOpen(next || null)}>
      <DialogTrigger asChild>
        <Button size="sm" variant="outline">
          <Plus aria-hidden className="h-4 w-4" />
          Add override
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Add override</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormField
              control={form.control}
              name="on_date"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Date</FormLabel>
                  <FormControl>
                    <Input type="date" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="kind"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Type</FormLabel>
                  <FormControl>
                    <RadioGroup className="flex gap-4" value={field.value} onValueChange={field.onChange}>
                      <div className="flex items-center gap-2 text-sm">
                        <RadioGroupItem id="exception-kind-blocked" value="blocked" />
                        <Label htmlFor="exception-kind-blocked">Blocked</Label>
                      </div>
                      <div className="flex items-center gap-2 text-sm">
                        <RadioGroupItem id="exception-kind-open" value="open" />
                        <Label htmlFor="exception-kind-open">Extra hours</Label>
                      </div>
                    </RadioGroup>
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <div className="form-row">
              <FormField
                control={form.control}
                name="start_time"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>{kind === "open" ? "Start time" : "Start time (optional)"}</FormLabel>
                    <FormControl>
                      <Input type="time" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="end_time"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>{kind === "open" ? "End time" : "End time (optional)"}</FormLabel>
                    <FormControl>
                      <Input type="time" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
            <FormSelectField
              control={form.control}
              label="Slot length"
              name="slot_minutes"
              options={SESSION_SLOT_LENGTH_OPTIONS}
            />
            <FormField
              control={form.control}
              name="note"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Note (optional)</FormLabel>
                  <FormControl>
                    <Textarea placeholder="Why this override exists" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <Button disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Adding…" : "Add override"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}

interface AvailabilityExceptionsProps {
  exceptions: AvailabilityException[];
}

/** One-off overrides — a blocked holiday or an extra open day outside the weekly grid. */
export function AvailabilityExceptions({ exceptions }: AvailabilityExceptionsProps) {
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [, startTransition] = useTransition();

  function handleDelete(id: string, date: string) {
    setPendingId(id);
    startTransition(async () => {
      const res = await deleteAvailabilityExceptionAction(id);
      setPendingId(null);
      if (res.error) {
        toast.error(res.error);
        return;
      }
      toast.success(`Override for ${date} removed.`);
    });
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-4">
        <h2 className="section-title">One-off overrides</h2>
        <AddOverrideDialog />
      </div>
      {exceptions.length === 0 ? (
        <div className="empty-state py-10">
          <p className="text-sm text-muted-foreground">No overrides yet — add one for a holiday or an extra open day.</p>
        </div>
      ) : (
        <ul className="flex flex-col gap-2">
          {exceptions.map((exc) => {
            const date = formatExceptionDate(exc.on_date);
            return (
              <li className="card-base flex flex-wrap items-center justify-between gap-3 p-4" key={exc.id}>
                <div className="flex min-w-0 flex-col gap-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-medium">{date}</span>
                    <Badge variant={exc.is_blocked ? "destructive" : "default"}>
                      {exc.is_blocked ? "Blocked" : "Extra hours"}
                    </Badge>
                  </div>
                  <p className="text-sm text-muted-foreground">{formatExceptionRange(exc)}</p>
                  {exc.note && <p className="text-sm text-muted-foreground">{exc.note}</p>}
                </div>
                <Button
                  aria-label={`Delete override for ${date}`}
                  disabled={pendingId === exc.id}
                  size="icon"
                  variant="ghost"
                  onClick={() => handleDelete(exc.id, date)}
                >
                  <Trash2 aria-hidden className="h-4 w-4" />
                </Button>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
