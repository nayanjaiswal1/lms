"use server";

import { revalidatePath } from "next/cache";
import { apiGet, apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import { forwardSetCookies } from "@/lib/server/set-cookie";
import ROUTES from "@/lib/routes";

// ─────────────────────────────────────────────
// Calendar wire-contract types — mirrors the /api/calendar/* backend contract.
// Declared here (not in lib/calendar/types.ts) because this is a shared-lib
// module (lib/server/**) and the boundaries lint only allows shared-lib to
// depend on shared-lib, never on a feature-lib — same reason MentorTicket is
// declared directly in lib/server/mentoring.ts rather than a feature file.
// These are type-only exports (interfaces/unions), so they don't conflict
// with Next's "use server" rule that every VALUE export must be an async
// function — types are erased at compile time and never reach that check.
// lib/calendar/types.ts re-exports them (type-only) for the calendar UI.
// ─────────────────────────────────────────────

// event_type includes the real, creatable types plus "assessment" — a
// read-only pseudo-type the backend stamps on virtual, non-persisted Event
// values synthesized from assessment due-windows (see Event.IsVirtual in
// backend/internal/calendar/models.go). Never send "assessment" when creating
// or updating an event; check is_virtual to gate the UI instead.
export type CalendarEventType = "mentor_session" | "live_class" | "deadline" | "custom" | "task" | "assessment";
export type CalendarEventPriority = "low" | "medium" | "high" | "urgent";
export type CalendarVisibility = "private" | "shared" | "public";
export type AttendeeRole = "owner" | "editor" | "viewer";
export type RsvpStatus = "pending" | "accepted" | "declined";
export type CalendarEventStatus = "scheduled" | "cancelled";
export type CalendarEventScope = "single" | "series";

export interface Attendee {
  event_id: string;
  user_id: string;
  role: AttendeeRole;
  rsvp_status: RsvpStatus;
  name?: string;
  email?: string;
}

export interface EventInvite {
  id: string;
  event_id: string;
  email: string;
  role: AttendeeRole;
  expires_at: string;
  accepted_at: string | null;
  created_at: string;
}

// Matches backend/internal/calendar's Event struct exactly — GET /events
// (list) returns this shape with no attendees. Fetch getEventAction(id) for
// the attendee-enriched detail (CalendarEventDetail) instead of assuming the
// list payload carries attendees.
export interface CalendarEvent {
  id: string;
  org_id: string;
  created_by: string;
  event_type: CalendarEventType;
  title: string;
  notes: string | null;
  meeting_url: string | null;
  starts_at: string; // UTC ISO 8601
  ends_at: string | null; // UTC ISO 8601 — null for an open-ended/all-day event
  all_day: boolean;
  visibility: CalendarVisibility;
  batch_id: string | null;
  course_id: string | null;
  recurrence_rule: string | null;
  status: CalendarEventStatus;
  // Meaningful only when event_type === "task": non-null once checked off.
  completed_at: string | null;
  // Meaningful only when event_type === "task".
  priority: CalendarEventPriority | null;
  is_virtual: boolean;
}

// Matches the GET /events/{id} response: the base event flattened alongside
// its attendee list and any not-yet-accepted external invites.
export interface CalendarEventDetail extends CalendarEvent {
  attendees: Attendee[];
  pending_invites: EventInvite[];
}

export interface CreateCalendarEventInput {
  event_type: CalendarEventType;
  title: string;
  notes?: string;
  meeting_url?: string;
  starts_at: string;
  ends_at?: string;
  all_day?: boolean;
  visibility: CalendarVisibility;
  batch_id?: string;
  course_id?: string;
  recurrence_rule?: string;
  // Only meaningful when event_type is "task".
  priority?: CalendarEventPriority;
  // Existing org members only — the backend's create/update endpoints only
  // accept attendee_user_ids (default role 'viewer'); to add a non-member by
  // email, or to grant 'owner'/'editor', call inviteAction after creation.
  attendee_user_ids?: string[];
}

export type UpdateCalendarEventInput = Partial<CreateCalendarEventInput>;

export async function listEventsAction(from: string, to: string): Promise<ActionResult<CalendarEvent[]>> {
  try {
    const params = new URLSearchParams({ from, to });
    const events = await apiGet<CalendarEvent[]>(`/api/calendar/events?${params.toString()}`);
    return { ok: true, data: events };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Could not load events." };
  }
}

// GET /events (list) never includes attendees — fetch this on demand (e.g.
// when the event side panel opens) for the attendee-enriched detail.
export async function getEventAction(id: string): Promise<ActionResult<CalendarEventDetail>> {
  try {
    const event = await apiGet<CalendarEventDetail>(`/api/calendar/events/${id}`);
    return { ok: true, data: event };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Could not load event." };
  }
}

// The .ics feed requires a per-user token (?token=...) minted via this
// endpoint — the bare /api/calendar/events.ics URL always 400s. Returns the
// full, ready-to-use feed URL (backend embeds the token in it).
export async function getIcsFeedUrlAction(): Promise<ActionResult<string>> {
  const result = await apiAction<{ url: string }>("POST", "/api/calendar/events.ics/token");
  if (!result.ok || !result.data) return { error: result.error ?? "Could not create a feed link." };
  return { ok: true, data: result.data.url };
}

export async function createEventAction(
  payload: CreateCalendarEventInput,
): Promise<ActionResult<CalendarEvent>> {
  const result = await apiAction<CalendarEvent>("POST", "/api/calendar/events", payload);
  if (result.ok) revalidatePath(ROUTES.CALENDAR);
  return result;
}

export async function updateEventAction(
  id: string,
  payload: UpdateCalendarEventInput,
  scope: CalendarEventScope = "single",
): Promise<ActionResult<CalendarEvent>> {
  const result = await apiAction<CalendarEvent>(
    "PATCH",
    `/api/calendar/events/${id}?scope=${scope}`,
    payload,
  );
  if (result.ok) revalidatePath(ROUTES.CALENDAR);
  return result;
}

export async function cancelEventAction(
  id: string,
  scope: CalendarEventScope = "single",
): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/calendar/events/${id}?scope=${scope}`);
  if (result.ok) revalidatePath(ROUTES.CALENDAR);
  return result;
}

export async function updateNotesAction(id: string, notes: string): Promise<ActionResult<CalendarEvent>> {
  return apiAction<CalendarEvent>("PATCH", `/api/calendar/events/${id}/notes`, { notes });
}

export async function setEventCompletedAction(id: string, completed: boolean): Promise<ActionResult<CalendarEvent>> {
  return apiAction<CalendarEvent>("PATCH", `/api/calendar/events/${id}/complete`, { completed });
}

// The backend returns the updated attendee row, not the whole event — the
// caller should splice it into its own attendee list rather than replace the
// event object.
export async function rsvpAction(id: string, status: RsvpStatus): Promise<ActionResult<Attendee>> {
  const result = await apiAction<Attendee>("POST", `/api/calendar/events/${id}/rsvp`, {
    rsvp_status: status,
  });
  if (result.ok) revalidatePath(ROUTES.CALENDAR);
  return result;
}

interface InviteResult {
  invite: EventInvite;
  token: string;
}

// Returns the created invite record (and its raw, one-time token — not
// currently surfaced in the UI since the invite email carries the link), not
// the event itself.
export async function inviteAction(
  id: string,
  email: string,
  role: AttendeeRole,
): Promise<ActionResult<InviteResult>> {
  const result = await apiAction<InviteResult>("POST", `/api/calendar/events/${id}/invite`, {
    email,
    role,
  });
  if (result.ok) revalidatePath(ROUTES.CALENDAR);
  return result;
}

// Accepting an external invite is unauthenticated and may bootstrap a brand
// new session for the invitee (account auto-created + logged in), mirroring
// the raw-fetch + forwardSetCookies pattern used by app/login/actions.ts and
// app/demo/actions.ts — apiAction can't be reused here because it only reads
// existing cookies, it never captures Set-Cookie from the response.
export async function acceptCalendarInviteAction(
  token: string,
): Promise<ActionResult<CalendarEvent>> {
  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) return { error: "Service unavailable." };

  let response: Response;
  try {
    response = await fetch(`${apiUrl}/api/calendar/invites/${token}/accept`, {
      method: "GET",
      cache: "no-store",
    });
  } catch {
    return { error: "Network error. Please try again." };
  }

  // AcceptInvite returns the full joined Event (title, starts_at, …), not a
  // {event_id, event_title} summary.
  const json = await response.json().catch(() => ({})) as {
    data?: CalendarEvent;
    error?: string;
  };
  if (!response.ok) return { error: json.error ?? "This invite link is invalid or has expired." };

  await forwardSetCookies(response.headers);
  return { ok: true, data: json.data };
}
