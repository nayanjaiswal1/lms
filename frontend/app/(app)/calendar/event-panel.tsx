"use client";

import * as React from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { MoreVertical, Pencil, Trash2, UserPlus } from "lucide-react";

import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetDescription } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Form } from "@/components/ui/form";
import { FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { formatTimeLabel } from "@/app/(app)/calendar/calendar-math";
import {
  cancelEventAction,
  inviteAction,
  rsvpAction,
  setEventCompletedAction,
  updateEventAction,
  updateNotesAction,
} from "@/lib/server/calendar";
import { ATTENDEE_ROLE_OPTIONS } from "@/lib/calendar/types";
import type {
  Attendee,
  AttendeeRole,
  CalendarEvent,
  CalendarEventScope,
  EventInvite,
  RsvpStatus,
} from "@/lib/calendar/types";

const RSVP_BADGE: Record<RsvpStatus, "default" | "secondary" | "destructive"> = {
  pending: "secondary",
  accepted: "default",
  declined: "destructive",
};

// An external invite can only ever grant 'editor' or 'viewer' — the backend
// rejects 'owner' here (IsValidInviteRole in backend/internal/calendar/models.go).
const INVITE_ROLE_OPTIONS = ATTENDEE_ROLE_OPTIONS.filter((opt) => opt.value !== "owner");

const InviteSchema = z.object({
  email: z.string().email("Enter a valid email."),
  role: z.enum(["editor", "viewer"]),
});
type InviteFormData = z.infer<typeof InviteSchema>;

function InviteForm({ eventId, onInvited }: { eventId: string; onInvited: (invite: EventInvite) => void }) {
  const form = useForm<InviteFormData>({
    resolver: zodResolver(InviteSchema),
    defaultValues: { email: "", role: "viewer" },
  });

  async function onSubmit(data: InviteFormData) {
    const result = await inviteAction(eventId, data.email, data.role as AttendeeRole);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Could not send invite.");
      return;
    }
    toast.success(`Invited ${data.email}.`);
    onInvited(result.data.invite);
    form.reset({ email: "", role: "viewer" });
  }

  return (
    <Form {...form}>
      <form className="flex items-end gap-2" onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="email"
          render={({ field }) => (
            <FormItem className="flex-1">
              <FormLabel className="sr-only">Email</FormLabel>
              <FormControl>
                <Input placeholder="Invite by email…" type="email" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <FormField
          control={form.control}
          name="role"
          render={({ field }) => (
            <FormItem className="w-full sm:w-32">
              <FormLabel className="sr-only">Role</FormLabel>
              <Select defaultValue={field.value} onValueChange={field.onChange}>
                <FormControl>
                  <SelectTrigger aria-label="Attendee role">
                    <SelectValue />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  {INVITE_ROLE_OPTIONS.map((opt) => (
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
        <Button disabled={form.formState.isSubmitting} size="icon" type="submit" variant="outline">
          <UserPlus aria-hidden className="h-4 w-4" />
          <span className="sr-only">Send invite</span>
        </Button>
      </form>
    </Form>
  );
}

const EditEventSchema = z.object({
  title: z.string().min(1, "Title is required.").max(200),
  date: z.string().min(1, "Date is required."),
  startTime: z.string().min(1, "Start time is required."),
  endTime: z.string().min(1, "End time is required."),
});
type EditEventFormData = z.infer<typeof EditEventSchema>;

function toDateInputValue(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

function toTimeInputValue(date: Date): string {
  return `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
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

function EditEventForm({ event, onSaved, onCancel }: EditEventFormProps) {
  const start = new Date(event.starts_at);
  const end = new Date(event.ends_at ?? event.starts_at);
  const form = useForm<EditEventFormData>({
    resolver: zodResolver(EditEventSchema),
    defaultValues: {
      title: event.title,
      date: toDateInputValue(start),
      startTime: toTimeInputValue(start),
      endTime: toTimeInputValue(end),
    },
  });

  async function submit(data: EditEventFormData, scope: CalendarEventScope) {
    const newStart = combineDateTime(data.date, data.startTime);
    const newEnd = combineDateTime(data.date, data.endTime);
    if (!(newEnd > newStart)) {
      form.setError("endTime", { message: "End time must be after start time." });
      return;
    }
    const result = await updateEventAction(
      event.id,
      { title: data.title, starts_at: newStart.toISOString(), ends_at: newEnd.toISOString() },
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
        <div className="flex flex-wrap justify-end gap-2">
          <Button disabled={form.formState.isSubmitting} size="sm" type="button" variant="ghost" onClick={onCancel}>
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

interface EventPanelProps {
  event: CalendarEvent;
  // null while the attendee-enriched detail (GET /events/{id}) is still
  // loading — the list endpoint this event came from never includes it.
  attendees: Attendee[] | null;
  // Same loading-null window as attendees — sent invites nobody has accepted yet.
  pendingInvites: EventInvite[] | null;
  currentUserId: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onAttendeeChanged: (attendee: Attendee) => void;
  onInvited: (invite: EventInvite) => void;
  // Also used after a full edit save, not just a notes save — both just
  // patch the changed CalendarEvent into the parent's list.
  onEventChanged: (event: CalendarEvent) => void;
  // Fired after a cancel or an edit save that may have detached a recurring
  // occurrence into a new event row — the parent just refetches the range
  // rather than trying to reconcile ids itself.
  onRefetchNeeded: () => void;
}

// The parent renders this with `key={event.id}` so switching to a different
// event fully remounts the panel — the notes draft below re-initializes from
// props naturally via React's own reconciliation, with no useEffect needed.
export function EventPanel({
  event,
  attendees,
  pendingInvites,
  currentUserId,
  open,
  onOpenChange,
  onAttendeeChanged,
  onInvited,
  onEventChanged,
  onRefetchNeeded,
}: EventPanelProps) {
  const [notes, setNotes] = React.useState(event.notes ?? "");
  const [isEditing, setIsEditing] = React.useState(false);
  const readOnly = event.is_virtual;

  async function saveNotes() {
    if (notes === (event.notes ?? "")) return;
    const result = await updateNotesAction(event.id, notes);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Could not save notes.");
      return;
    }
    onEventChanged(result.data);
  }

  async function handleToggleComplete(completed: boolean) {
    const result = await setEventCompletedAction(event.id, completed);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Could not update task.");
      return;
    }
    onEventChanged(result.data);
  }

  async function handleRsvp(status: RsvpStatus) {
    const result = await rsvpAction(event.id, status);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Could not update RSVP.");
      return;
    }
    onAttendeeChanged(result.data);
  }

  async function handleCancel(scope: "single" | "series") {
    const result = await cancelEventAction(event.id, scope);
    if (!result.ok) {
      toast.error(result.error ?? "Could not cancel event.");
      return;
    }
    toast.success("Event cancelled.");
    onRefetchNeeded();
    onOpenChange(false);
  }

  function handleEventSaved(updated: CalendarEvent) {
    setIsEditing(false);
    onEventChanged(updated);
    onRefetchNeeded();
  }

  const start = new Date(event.starts_at);
  const end = new Date(event.ends_at ?? event.starts_at);
  const myAttendance = attendees?.find((a) => a.user_id === currentUserId);

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="modal-responsive flex w-full flex-col gap-6 overflow-y-auto p-6 sm:max-w-md" side="right">
        <SheetHeader className="flex-row items-start justify-between gap-2 p-0 pr-8">
          <div className="flex flex-col gap-1.5">
            <SheetTitle>{event.title}</SheetTitle>
            <SheetDescription>
              {event.all_day
                ? start.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })
                : `${start.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })} · ${formatTimeLabel(start)} – ${formatTimeLabel(end)}`}
            </SheetDescription>
          </div>
          {!readOnly && event.status !== "cancelled" && !isEditing && (
            <div className="flex shrink-0 items-center gap-1">
              <Button aria-label="Edit event" size="icon" variant="ghost" onClick={() => setIsEditing(true)}>
                <Pencil aria-hidden className="h-4 w-4" />
              </Button>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button aria-label="Event actions" size="icon" variant="ghost">
                    <MoreVertical aria-hidden className="h-4 w-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  {event.recurrence_rule ? (
                    <>
                      <DropdownMenuItem className="text-destructive focus:text-destructive" onClick={() => void handleCancel("single")}>
                        <Trash2 aria-hidden className="mr-1.5 h-4 w-4" />
                        Cancel this event
                      </DropdownMenuItem>
                      <DropdownMenuItem className="text-destructive focus:text-destructive" onClick={() => void handleCancel("series")}>
                        <Trash2 aria-hidden className="mr-1.5 h-4 w-4" />
                        Cancel entire series
                      </DropdownMenuItem>
                    </>
                  ) : (
                    <DropdownMenuItem className="text-destructive focus:text-destructive" onClick={() => void handleCancel("single")}>
                      <Trash2 aria-hidden className="mr-1.5 h-4 w-4" />
                      Cancel event
                    </DropdownMenuItem>
                  )}
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          )}
        </SheetHeader>

        {!isEditing && !readOnly && event.event_type === "task" && (
          <label className="flex w-fit items-center gap-2 text-sm">
            <input
              checked={Boolean(event.completed_at)}
              className="h-4 w-4"
              type="checkbox"
              onChange={(e) => void handleToggleComplete(e.target.checked)}
            />
            Mark as done
          </label>
        )}

        {isEditing && <EditEventForm event={event} onCancel={() => setIsEditing(false)} onSaved={handleEventSaved} />}

        {!isEditing && readOnly && (
          <p className="rounded-md border border-border bg-muted px-3 py-2 text-sm text-muted-foreground">
            This is an assessment window — it can&apos;t be edited, RSVPed to, or shared from the calendar.
          </p>
        )}

        {!isEditing && !readOnly && myAttendance && myAttendance.role !== "owner" && (
          <div className="flex items-center justify-between gap-2">
            <span className="text-sm text-muted-foreground">Your RSVP</span>
            <div className="flex items-center gap-2">
              <Badge variant={RSVP_BADGE[myAttendance.rsvp_status]}>{myAttendance.rsvp_status}</Badge>
              <Button
                disabled={myAttendance.rsvp_status === "accepted"}
                size="sm"
                variant="outline"
                onClick={() => handleRsvp("accepted")}
              >
                Accept
              </Button>
              <Button
                disabled={myAttendance.rsvp_status === "declined"}
                size="sm"
                variant="outline"
                onClick={() => handleRsvp("declined")}
              >
                Decline
              </Button>
            </div>
          </div>
        )}

        {!isEditing && (
        <div className="flex flex-col gap-2">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium">Notes</span>
            {!readOnly && (
              <Button
                disabled={notes === (event.notes ?? "")}
                size="sm"
                variant="outline"
                onClick={() => void saveNotes()}
              >
                Save
              </Button>
            )}
          </div>
          <Textarea
            aria-label="Event notes"
            disabled={readOnly}
            placeholder="Add notes…"
            rows={4}
            value={notes}
            onBlur={saveNotes}
            onChange={(e) => setNotes(e.target.value)}
          />
        </div>
        )}

        {!isEditing && !readOnly && (
          <div className="flex flex-col gap-2">
            <span className="text-sm font-medium">Attendees</span>
            {attendees === null ? (
              <p className="text-sm text-muted-foreground">Loading attendees…</p>
            ) : attendees.length === 0 ? (
              <p className="text-sm text-muted-foreground">No attendees yet.</p>
            ) : (
              <ul className="flex flex-col gap-1.5">
                {attendees.map((a) => (
                  <li className="flex items-center justify-between gap-2 text-sm" key={a.user_id}>
                    <span className="truncate">{a.name ?? a.email ?? a.user_id}</span>
                    <span className="flex shrink-0 items-center gap-1.5">
                      {a.role === "owner" ? (
                        <Badge variant="outline">Organizer</Badge>
                      ) : (
                        <>
                          <Badge variant="outline">{a.role}</Badge>
                          <Badge variant={RSVP_BADGE[a.rsvp_status]}>{a.rsvp_status}</Badge>
                        </>
                      )}
                    </span>
                  </li>
                ))}
              </ul>
            )}
            {pendingInvites && pendingInvites.length > 0 && (
              <ul className="flex flex-col gap-1.5">
                {pendingInvites.map((inv) => (
                  <li className="flex items-center justify-between gap-2 text-sm" key={inv.id}>
                    <span className="truncate text-muted-foreground">{inv.email}</span>
                    <span className="flex shrink-0 items-center gap-1.5">
                      <Badge variant="outline">{inv.role}</Badge>
                      <Badge variant="secondary">Invited</Badge>
                    </span>
                  </li>
                ))}
              </ul>
            )}
            <InviteForm eventId={event.id} onInvited={onInvited} />
          </div>
        )}
      </SheetContent>
    </Sheet>
  );
}
