"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import Link from "next/link";
import { CalendarPlus } from "lucide-react";

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
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import ROUTES from "@/lib/routes";
import {
  bookBatchSessionAction,
  bookSessionAction,
  type Slot,
} from "@/lib/server/sessions";
import { SlotPicker } from "./slot-picker";

const BookSchema = z.object({
  title: z.string().max(200, "Keep the title under 200 characters.").optional(),
  agenda: z.string().max(2000, "Keep the agenda under 2000 characters.").optional(),
});
type BookFormData = z.infer<typeof BookSchema>;

interface BookSessionDialogProps {
  /** The mentor being booked. Omit only in batch mode, where `mentors` lets
   * the scheduler choose which mentor runs the session. */
  mentorId?: string;
  mentorName?: string;
  requireCredits: boolean;
  balance: number;
  defaultDurationMinutes: number;
  /** Set when a mentor is booking a session with a mentee — omit when a
   * student is booking a session with a mentor for themselves. */
  studentId?: string;
  /** Set to schedule for a whole cohort instead of one student. Batch
   * sessions are permission-gated server-side and cost no credits, so the
   * credit gate below is skipped for them. */
  batchId?: string;
  /** Mentor choices, batch mode only — the scheduler is an admin/instructor
   * who is not necessarily the mentor running the session. */
  mentors?: { value: string; label: string }[];
  triggerLabel?: string;
  className?: string;
}

interface Selection {
  mentorId: string;
  slot: Slot | null;
}

export function BookSessionDialog({
  mentorId,
  mentorName,
  requireCredits,
  balance,
  defaultDurationMinutes,
  studentId,
  batchId,
  mentors,
  triggerLabel = "Book a session",
  className,
}: BookSessionDialogProps) {
  const router = useRouter();

  // Budget: exactly the 2 useState calls this component gets. `open` is the
  // dialog's own visibility; `pick` bundles the chosen mentor and slot, which
  // always change together (switching mentor invalidates the slot).
  const [open, setOpen] = React.useState(false);
  const [pick, setPick] = React.useState<Selection>({
    mentorId: mentorId ?? mentors?.[0]?.value ?? "",
    slot: null,
  });

  const form = useForm<BookFormData>({
    resolver: zodResolver(BookSchema),
    defaultValues: { title: "", agenda: "" },
  });

  async function onSubmit(data: BookFormData) {
    if (!pick.slot) {
      toast.error("Pick a time first.");
      return;
    }
    const slotPayload = {
      starts_at: pick.slot.starts_at,
      ends_at: pick.slot.ends_at,
      title: data.title || undefined,
      agenda: data.agenda || undefined,
    };
    const result = batchId
      ? await bookBatchSessionAction(batchId, { mentor_id: pick.mentorId, ...slotPayload })
      : await bookSessionAction({ mentor_id: pick.mentorId, student_id: studentId, ...slotPayload });

    if (!result.ok) {
      const message = result.error ?? "Could not book the session.";
      // The backend has no machine-readable error code on this action result
      // (see ActionResult in lib/server/api.ts), so the insufficient-credits
      // case is told apart by its wording — see backend/internal/sessions/
      // handler.go's ErrInsufficientCredits message ("...session credits...").
      if (/credit/i.test(message)) {
        toast.error(message, {
          action: { label: "Buy credits", onClick: () => router.push(ROUTES.SESSION_CREDITS) },
        });
      } else {
        toast.error(message);
      }
      return;
    }

    const bookedWith = mentors?.find((m) => m.value === pick.mentorId)?.label ?? mentorName;
    toast.success(batchId ? "Session scheduled for the whole batch." : `Session booked with ${bookedWith}.`);
    form.reset({ title: "", agenda: "" });
    setPick((p) => ({ ...p, slot: null }));
    setOpen(false);
  }

  // Batch sessions are scheduled by staff and charge no student credits, so
  // the buy-credits gate applies to 1:1 booking only.
  if (!batchId && requireCredits && balance <= 0) {
    return (
      <Button asChild className={className} size="default">
        <Link href={ROUTES.SESSION_CREDITS}>Buy credits to book a session</Link>
      </Button>
    );
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className={className} size="default">
          <CalendarPlus aria-hidden className="mr-1.5 h-4 w-4" />
          {triggerLabel}
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>
            {batchId ? "Schedule a session for this batch" : `Book a session with ${mentorName}`}
          </DialogTitle>
          <DialogDescription>
            {batchId
              ? `Every member of the batch is invited and the session lands on their calendar. Pick a day, then an open slot (~${defaultDurationMinutes} min each).`
              : `Pick a day, then an open time slot (~${defaultDurationMinutes} min each).`}
          </DialogDescription>
        </DialogHeader>

        {mentors && mentors.length > 0 && (
          <div className="flex flex-col gap-2">
            <Label htmlFor="batch-session-mentor">Mentor</Label>
            <Select
              value={pick.mentorId}
              onValueChange={(next) => setPick({ mentorId: next, slot: null })}
            >
              <SelectTrigger id="batch-session-mentor">
                <SelectValue placeholder="Choose a mentor" />
              </SelectTrigger>
              <SelectContent>
                {mentors.map((m) => (
                  <SelectItem key={m.value} value={m.value}>
                    {m.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        )}

        <SlotPicker mentorId={pick.mentorId} onSelect={(slot) => setPick((p) => ({ ...p, slot }))} />

        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Title (optional)" name="title" placeholder="Mentor session" />
            <FormField
              control={form.control}
              name="agenda"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Agenda (optional)</FormLabel>
                  <FormControl>
                    <Textarea placeholder="What do you want to cover?" rows={3} {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <DialogFooter>
              <Button
                disabled={form.formState.isSubmitting || !pick.slot || !pick.mentorId}
                type="submit"
              >
                {form.formState.isSubmitting ? "Booking…" : batchId ? "Schedule session" : "Book session"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
