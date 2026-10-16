"use client";

import * as React from "react";
import { toast } from "sonner";
import { MoreVertical, Pencil, Trash2 } from "lucide-react";

import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetDescription } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Checkbox } from "@/components/ui/checkbox";
import { formatTimeLabel } from "@/app/(app)/calendar/calendar-math";
import { layerMetaFor, primaryLayerFor } from "@/app/(app)/calendar/event-block";
import { EditEventForm } from "@/app/(app)/calendar/edit-event-form";
import { EventAttendees, RSVP_BADGE } from "@/app/(app)/calendar/event-attendees";
import { useMediaQuery } from "@/hooks/use-media-query";
import {
  cancelEventAction,
  rsvpAction,
  setEventCompletedAction,
  updateNotesAction,
} from "@/lib/server/calendar";
import { CALENDAR_PRIORITY_OPTIONS } from "@/lib/calendar/types";
import type { Attendee, CalendarEvent, CalendarEventPriority, EventInvite, RsvpStatus } from "@/lib/calendar/types";
import { cn } from "@/lib/utils";


const PRIORITY_LABEL = Object.fromEntries(
  CALENDAR_PRIORITY_OPTIONS.map((opt) => [opt.value, opt.label]),
) as Record<CalendarEventPriority, string>;
const PRIORITY_BADGE_CLASS = Object.fromEntries(
  CALENDAR_PRIORITY_OPTIONS.map((opt) => [opt.value, opt.badgeClassName]),
) as Record<CalendarEventPriority, string>;

const DESKTOP_QUERY = "(min-width: 640px)";

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
  const layer = layerMetaFor(primaryLayerFor(event, currentUserId));
  const isDesktop = useMediaQuery(DESKTOP_QUERY);

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      {/* Bottom sheet on phones (thumb-reachable, page stays visible above),
          right-hand side panel from sm up. */}
      <SheetContent
        className={cn(
          "flex w-full flex-col gap-6 overflow-y-auto",
          isDesktop ? "sm:max-w-md" : "safe-bottom max-h-[85dvh] rounded-t-2xl pt-3",
        )}
        side={isDesktop ? "right" : "bottom"}
      >
        {!isDesktop && <span aria-hidden className="mx-auto h-1.5 w-10 shrink-0 rounded-pill bg-border" />}
        <SheetHeader className="flex-row items-start justify-between gap-2 pr-8">
          <div className="flex min-w-0 flex-col gap-1.5">
            <span className={cn("inline-flex w-fit items-center gap-1.5 rounded-pill border px-2 py-0.5 text-xs font-medium", layer.badgeClassName)}>
              <span aria-hidden className={cn("h-2 w-2 rounded-full", layer.swatchClassName)} />
              {layer.label}
            </span>
            <SheetTitle className={cn("break-words", event.status === "cancelled" && "line-through opacity-70")}>{event.title}</SheetTitle>
            <SheetDescription>
              {event.all_day
                ? start.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })
                : `${start.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })} · ${formatTimeLabel(start)} – ${formatTimeLabel(end)}`}
            </SheetDescription>
          </div>
          {!readOnly && event.status !== "cancelled" && !isEditing && (
            <div className="flex shrink-0 items-center gap-1">
              <Button aria-label="Edit event" className="touch-target" size="icon" variant="ghost" onClick={() => setIsEditing(true)}>
                <Pencil aria-hidden className="h-4 w-4" />
              </Button>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button aria-label="Event actions" className="touch-target" size="icon" variant="ghost">
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
          <div className="flex-between gap-2">
            <label className="flex min-h-11 w-fit cursor-pointer items-center gap-3 text-sm font-medium" htmlFor="event-mark-done">
              <Checkbox
                checked={Boolean(event.completed_at)}
                className="h-5 w-5"
                id="event-mark-done"
                onCheckedChange={(v) => void handleToggleComplete(v === true)}
              />
              Mark as done
            </label>
            {event.priority && (
              <Badge className={PRIORITY_BADGE_CLASS[event.priority]} variant="outline">
                {PRIORITY_LABEL[event.priority]}
              </Badge>
            )}
          </div>
        )}

        {isEditing && <EditEventForm event={event} onCancel={() => setIsEditing(false)} onSaved={handleEventSaved} />}

        {!isEditing && readOnly && (
          <p className="rounded-md border border-border bg-muted px-3 py-2 text-sm text-muted-foreground">
            This is an assessment window — it can&apos;t be edited, RSVPed to, or shared from the calendar.
          </p>
        )}

        {!isEditing && !readOnly && myAttendance && myAttendance.role !== "owner" && (
          <div className="flex-between gap-2">
            <span className="text-sm text-muted-foreground">Your RSVP</span>
            <div className="flex flex-wrap items-center justify-end gap-2">
              <Badge variant={RSVP_BADGE[myAttendance.rsvp_status]}>{myAttendance.rsvp_status}</Badge>
              <Button
                disabled={myAttendance.rsvp_status === "accepted"}
                className="touch-target-dense"
                size="sm"
                variant="outline"
                onClick={() => handleRsvp("accepted")}
              >
                Accept
              </Button>
              <Button
                disabled={myAttendance.rsvp_status === "declined"}
                className="touch-target-dense"
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
          <div className="flex-between">
            <span className="text-sm font-semibold">Notes</span>
            {!readOnly && (
              <Button
                className="touch-target-dense"
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
          <EventAttendees attendees={attendees} eventId={event.id} pendingInvites={pendingInvites} onInvited={onInvited} />
        )}
      </SheetContent>
    </Sheet>
  );
}
