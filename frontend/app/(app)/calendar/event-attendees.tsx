"use client";

import { Badge } from "@/components/ui/badge";
import { InviteForm } from "@/app/(app)/calendar/invite-form";
import type { Attendee, EventInvite, RsvpStatus } from "@/lib/calendar/types";

export const RSVP_BADGE: Record<RsvpStatus, "default" | "secondary" | "destructive"> = {
  pending: "secondary",
  accepted: "default",
  declined: "destructive",
};

interface EventAttendeesProps {
  eventId: string;
  // null while GET /events/{id} is still loading.
  attendees: Attendee[] | null;
  pendingInvites: EventInvite[] | null;
  onInvited: (invite: EventInvite) => void;
}

export function EventAttendees({ eventId, attendees, pendingInvites, onInvited }: EventAttendeesProps) {
  return (
        <div className="flex flex-col gap-2">
          <span className="text-sm font-semibold">Attendees</span>
          {attendees === null ? (
            <div aria-busy className="flex flex-col gap-2">
              <span className="sr-only">Loading attendees…</span>
              <span className="skeleton h-4 w-3/4" />
              <span className="skeleton h-4 w-1/2" />
            </div>
          ) : attendees.length === 0 ? (
            <p className="text-sm text-muted-foreground">No attendees yet.</p>
          ) : (
            <ul className="flex flex-col gap-1.5">
              {attendees.map((a) => (
                <li className="flex-between gap-2 text-sm" key={a.user_id}>
                  <span className="min-w-0 truncate">{a.name ?? a.email ?? a.user_id}</span>
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
                <li className="flex-between gap-2 text-sm" key={inv.id}>
                  <span className="min-w-0 truncate text-muted-foreground">{inv.email}</span>
                  <span className="flex shrink-0 items-center gap-1.5">
                    <Badge variant="outline">{inv.role}</Badge>
                    <Badge variant="secondary">Invited</Badge>
                  </span>
                </li>
              ))}
            </ul>
          )}
          <InviteForm eventId={eventId} onInvited={onInvited} />
        </div>
  );
}
