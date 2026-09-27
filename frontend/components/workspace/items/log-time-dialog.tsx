"use client";

import { useState, type ReactNode } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Clock } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import { logTimeAction, updateTimeLogAction } from "@/lib/workspace/phase4-actions";
import type { TimeLog } from "@/lib/workspace/types";

// Mirrors backend/internal/workspace/models_phase4.go's TimeLogMaxMinutes (720)
// and TimeLogNoteMaxLen (1000) — the client-side bound is a UX nicety, the
// server re-validates regardless. Minutes stays a string field (same
// string-then-Number()-at-submit pattern as checkpoint-dialog.tsx) rather
// than z.coerce.number(), which react-hook-form's generic resolver typing
// can't reconcile with a plain <input type="number"> value.
const Schema = z.object({
  minutes: z.string().refine((v) => {
    const n = Number(v);
    return v !== "" && Number.isInteger(n) && n >= 1 && n <= 720;
  }, "Enter 1-720 minutes."),
  logged_on: z.string().min(1, "Pick a date."),
  note: z.string().max(1000, "Note must be 1000 characters or fewer.").optional(),
});
type FormData = z.infer<typeof Schema>;

function todayISO(): string {
  return new Date().toISOString().slice(0, 10);
}

interface LogTimeDialogProps {
  workspaceId: string;
  itemId: string;
  /** Set to edit an existing (still-editable) log instead of creating one. */
  editing?: TimeLog;
  trigger?: ReactNode;
}

export function LogTimeDialog({ workspaceId, itemId, editing, trigger }: LogTimeDialogProps) {
  const [open, setOpen] = useState(false);
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      minutes: String(editing?.minutes ?? 60),
      logged_on: editing?.logged_on ?? todayISO(),
      note: editing?.note ?? "",
    },
  });

  async function onSubmit(data: FormData) {
    const input = { minutes: Number(data.minutes), logged_on: data.logged_on, note: data.note || null };
    const result = editing
      ? await updateTimeLogAction(workspaceId, editing.id, input)
      : await logTimeAction(workspaceId, itemId, input);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(editing ? "Time log updated." : "Time logged.");
    setOpen(false);
    form.reset();
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {trigger ?? (
          <Button className="gap-2" size="sm" variant="outline">
            <Clock aria-hidden className="h-4 w-4" />
            Log time
          </Button>
        )}
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>{editing ? "Edit time log" : "Log time"}</DialogTitle>
          <DialogDescription>
            {editing
              ? "Logs can only be edited within 7 days of when they were created."
              : "1–720 minutes per entry, up to 24 hours total per day."}
          </DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Minutes" max={720} min={1} name="minutes" type="number" />
            <FormInputField control={form.control} label="Date" max={todayISO()} name="logged_on" type="date" />
            <FormTextareaField control={form.control} label="Note (optional)" name="note" rows={3} />
            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Saving…" : editing ? "Save changes" : "Log time"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
