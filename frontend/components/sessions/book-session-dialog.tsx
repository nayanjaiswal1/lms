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
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";
import { bookSessionAction, getMentorSlotsAction, type Slot } from "@/lib/server/sessions";
import { SlotGrid } from "./slot-grid";

const DAYS_AHEAD = 14;

const BookSchema = z.object({
  title: z.string().max(200, "Keep the title under 200 characters.").optional(),
  agenda: z.string().max(2000, "Keep the agenda under 2000 characters.").optional(),
});
type BookFormData = z.infer<typeof BookSchema>;

interface DayOption {
  key: string;
  weekday: string;
  dayLabel: string;
}

/** Local-calendar-day key (yyyy-mm-dd) — avoids the UTC date shift that
 * `toISOString().slice(0, 10)` would introduce for timezones behind UTC. */
function dateKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function buildDayOptions(): DayOption[] {
  const today = new Date();
  return Array.from({ length: DAYS_AHEAD }, (_, i) => {
    const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() + i);
    return {
      key: dateKey(d),
      weekday: d.toLocaleDateString(undefined, { weekday: "short" }),
      dayLabel: d.toLocaleDateString(undefined, { day: "numeric", month: "short" }),
    };
  });
}

function dayBounds(key: string): { from: string; to: string } {
  const [y, m, d] = key.split("-").map(Number);
  return {
    from: new Date(y, m - 1, d, 0, 0, 0, 0).toISOString(),
    to: new Date(y, m - 1, d, 23, 59, 59, 999).toISOString(),
  };
}

interface BookSessionDialogProps {
  mentorId: string;
  mentorName: string;
  requireCredits: boolean;
  balance: number;
  defaultDurationMinutes: number;
  /** Set when a mentor is booking a session with a mentee — omit when a
   * student is booking a session with a mentor for themselves. */
  studentId?: string;
  triggerLabel?: string;
  className?: string;
}

interface DayView {
  day: string;
  slots: Slot[];
  loading: boolean;
  selectedSlot: Slot | null;
}

export function BookSessionDialog({
  mentorId,
  mentorName,
  requireCredits,
  balance,
  defaultDurationMinutes,
  studentId,
  triggerLabel = "Book a session",
  className,
}: BookSessionDialogProps) {
  const days = React.useMemo(buildDayOptions, []);
  const router = useRouter();

  // Budget: exactly the 2 useState calls this component gets. `open` is the
  // dialog's own visibility; `view` bundles the selected day, its fetched
  // slots, the in-flight flag, and the chosen slot into one unit, since they
  // always change together (picking a day clears the old slots + selection).
  const [open, setOpen] = React.useState(false);
  const [view, setView] = React.useState<DayView>({
    day: days[0].key,
    slots: [],
    loading: false,
    selectedSlot: null,
  });

  const form = useForm<BookFormData>({
    resolver: zodResolver(BookSchema),
    defaultValues: { title: "", agenda: "" },
  });

  async function loadDay(day: string) {
    setView((v) => ({ ...v, day, loading: true, selectedSlot: null }));
    const { from, to } = dayBounds(day);
    const result = await getMentorSlotsAction(mentorId, from, to);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Couldn't load times for that day.");
      setView((v) => ({ ...v, loading: false, slots: [] }));
      return;
    }
    const { slots } = result.data;
    setView((v) => ({ ...v, loading: false, slots }));
  }

  function handleOpenChange(next: boolean) {
    setOpen(next);
    if (next) void loadDay(view.day);
  }

  async function onSubmit(data: BookFormData) {
    if (!view.selectedSlot) {
      toast.error("Pick a time first.");
      return;
    }
    const result = await bookSessionAction({
      mentor_id: mentorId,
      student_id: studentId,
      starts_at: view.selectedSlot.starts_at,
      ends_at: view.selectedSlot.ends_at,
      title: data.title || undefined,
      agenda: data.agenda || undefined,
    });
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
    toast.success(`Session booked with ${mentorName}.`);
    form.reset({ title: "", agenda: "" });
    setView((v) => ({ ...v, selectedSlot: null }));
    setOpen(false);
  }

  if (requireCredits && balance <= 0) {
    return (
      <Button asChild className={className} size="default">
        <Link href={ROUTES.SESSION_CREDITS}>Buy credits to book a session</Link>
      </Button>
    );
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>
        <Button className={className} size="default">
          <CalendarPlus aria-hidden className="mr-1.5 h-4 w-4" />
          {triggerLabel}
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Book a session with {mentorName}</DialogTitle>
          <DialogDescription>
            Pick a day, then an open time slot (~{defaultDurationMinutes} min each).
          </DialogDescription>
        </DialogHeader>

        <div aria-label="Choose a day" className="flex gap-2 overflow-x-auto pb-2" role="tablist">
          {days.map((d) => (
            <button
              aria-selected={view.day === d.key}
              className={cn(
                "flex min-w-16 shrink-0 flex-col items-center gap-0.5 rounded-md border border-border px-3 py-2 text-sm transition-colors duration-fast touch-target",
                view.day === d.key
                  ? "border-primary bg-primary text-primary-foreground"
                  : "bg-background hover:bg-accent hover:text-accent-foreground",
              )}
              key={d.key}
              role="tab"
              type="button"
              onClick={() => void loadDay(d.key)}
            >
              <span className="text-xs uppercase tracking-wide opacity-80">{d.weekday}</span>
              <span className="font-semibold">{d.dayLabel}</span>
            </button>
          ))}
        </div>

        <SlotGrid
          loading={view.loading}
          selected={view.selectedSlot?.starts_at ?? null}
          slots={view.slots}
          onSelect={(startsAt) => {
            const slot = view.slots.find((s) => s.starts_at === startsAt) ?? null;
            setView((v) => ({ ...v, selectedSlot: slot }));
          }}
        />

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
              <Button disabled={form.formState.isSubmitting || !view.selectedSlot} type="submit">
                {form.formState.isSubmitting ? "Booking…" : "Book session"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
