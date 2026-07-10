"use client";

import * as React from "react";
import { toast } from "sonner";
import { parseAsArrayOf, parseAsString, parseAsStringEnum, useQueryState } from "nuqs";

import { createEventAction, getEventAction, getIcsFeedUrlAction, listEventsAction, setEventCompletedAction, updateEventAction } from "@/lib/server/calendar";
import { CALENDAR_LAYER, CALENDAR_VIEW } from "@/lib/calendar/types";
import type { Attendee, CalendarEvent, CalendarEventDetail, CalendarLayer, CalendarView, EventInvite } from "@/lib/calendar/types";
import {
  formatRangeLabel,
  getWeekDays,
  isoDateParam,
  minutesSinceMidnight,
  rangeForView,
  snapMinutes,
  startOfDay,
  stepAnchor,
} from "@/app/(app)/calendar/calendar-math";
import { CalendarToolbar } from "@/app/(app)/calendar/calendar-toolbar";
import { MonthView } from "@/app/(app)/calendar/month-view";
import { TimeGridView } from "@/app/(app)/calendar/time-grid-view";
import { AgendaView } from "@/app/(app)/calendar/agenda-view";
import { EventPanel } from "@/app/(app)/calendar/event-panel";

const ALL_LAYERS = Object.values(CALENDAR_LAYER) as CalendarLayer[];
const VIEW_VALUES = Object.values(CALENDAR_VIEW) as CalendarView[];

type Interaction =
  | { kind: "idle" }
  | { kind: "resizing"; eventId: string; deltaMinutes: number }
  | { kind: "creatingDay"; day: string }
  | { kind: "creatingSlot"; day: string; minutes: number };

interface GridState {
  events: CalendarEvent[];
  error?: string;
  interaction: Interaction;
  // GET /events (list) never includes attendees, so the side panel fetches
  // the attendee-enriched detail separately (see handleEventClick) and it
  // lives here, keyed by event id, rather than being assumed present on the
  // list-loaded CalendarEvent.
  eventDetail: CalendarEventDetail | null;
}

type GridAction =
  | { type: "setEvents"; events: CalendarEvent[]; error?: string }
  | { type: "patchEvent"; event: CalendarEvent }
  | { type: "setEventDetail"; detail: CalendarEventDetail | null }
  | { type: "patchAttendee"; attendee: Attendee }
  | { type: "addPendingInvite"; invite: EventInvite }
  | { type: "startResize"; eventId: string }
  | { type: "updateResize"; deltaMinutes: number }
  | { type: "clearInteraction" }
  | { type: "startCreateDay"; day: string }
  | { type: "startCreateSlot"; day: string; minutes: number };

function gridReducer(state: GridState, action: GridAction): GridState {
  switch (action.type) {
    case "setEvents":
      return { ...state, events: action.events, error: action.error };
    case "patchEvent": {
      const exists = state.events.some((e) => e.id === action.event.id);
      return {
        ...state,
        events: exists
          ? state.events.map((e) => (e.id === action.event.id ? action.event : e))
          : [...state.events, action.event],
      };
    }
    case "setEventDetail":
      return { ...state, eventDetail: action.detail };
    case "patchAttendee": {
      if (!state.eventDetail) return state;
      const exists = state.eventDetail.attendees.some((a) => a.user_id === action.attendee.user_id);
      return {
        ...state,
        eventDetail: {
          ...state.eventDetail,
          // Merge rather than replace: the RSVP endpoint only returns
          // {event_id, user_id, role, rsvp_status} — no name/email — so a
          // full replace would blank out the name already loaded from
          // GET /events/{id}.
          attendees: exists
            ? state.eventDetail.attendees.map((a) =>
                a.user_id === action.attendee.user_id ? { ...a, ...action.attendee } : a,
              )
            : [...state.eventDetail.attendees, action.attendee],
        },
      };
    }
    case "addPendingInvite": {
      if (!state.eventDetail) return state;
      return {
        ...state,
        eventDetail: {
          ...state.eventDetail,
          pending_invites: [action.invite, ...(state.eventDetail.pending_invites ?? [])],
        },
      };
    }
    case "startResize":
      return { ...state, interaction: { kind: "resizing", eventId: action.eventId, deltaMinutes: 0 } };
    case "updateResize":
      return state.interaction.kind === "resizing"
        ? { ...state, interaction: { ...state.interaction, deltaMinutes: action.deltaMinutes } }
        : state;
    case "clearInteraction":
      return { ...state, interaction: { kind: "idle" } };
    case "startCreateDay":
      return { ...state, interaction: { kind: "creatingDay", day: action.day } };
    case "startCreateSlot":
      return { ...state, interaction: { kind: "creatingSlot", day: action.day, minutes: action.minutes } };
    default:
      return state;
  }
}

function layerMatches(layer: CalendarLayer, event: CalendarEvent, currentUserId: string): boolean {
  switch (layer) {
    case "mine":
      return event.created_by === currentUserId;
    case "batch":
      return event.batch_id !== null;
    case "course":
      return event.course_id !== null;
    case "mentor":
      return event.event_type === "mentor_session";
    case "assessment":
      return event.is_virtual;
  }
}

interface CalendarGridProps {
  currentUserId: string;
  initialAnchor: string;
  initialEvents: CalendarEvent[];
  initialError?: string;
  initialView: CalendarView;
}

export function CalendarGrid({ currentUserId, initialAnchor, initialEvents, initialError, initialView }: CalendarGridProps) {
  const [view, setView] = useQueryState("view", parseAsStringEnum<CalendarView>(VIEW_VALUES).withDefault(initialView));
  const [dateParam, setDateParam] = useQueryState("date", parseAsString.withDefault(initialAnchor));
  const [search, setSearch] = useQueryState("q", parseAsString.withDefault(""));
  const [activeLayers, setActiveLayers] = useQueryState(
    "layers",
    parseAsArrayOf(parseAsStringEnum<CalendarLayer>(ALL_LAYERS)).withDefault(ALL_LAYERS),
  );
  const [selectedEventId, setSelectedEventId] = useQueryState("event", parseAsString);

  const [state, dispatch] = React.useReducer(gridReducer, {
    events: initialEvents,
    error: initialError,
    interaction: { kind: "idle" },
    eventDetail: null,
  });

  // Tracks which event id the attendee-enriched detail has already been
  // fetched for. selectedEventId can become non-null two ways — a grid
  // click (handleEventClick) or the URL already carrying ?event=<id> on
  // first load (e.g. the dashboard's "Upcoming" widget link) — so the fetch
  // is triggered here, once per id, rather than only from the click handler,
  // otherwise a direct link would open the panel with attendees stuck on
  // "loading" forever. A ref (not state) avoids an extra render just to
  // track this, and guards against re-fetching on every render.
  const detailFetchedForRef = React.useRef<string | null>(null);

  function handleEventClick(id: string) {
    void setSelectedEventId(id);
  }

  const anchor = new Date(dateParam);

  async function refetch(nextView: CalendarView, nextAnchor: Date) {
    const { from, to } = rangeForView(nextView, nextAnchor);
    const result = await listEventsAction(isoDateParam(from), isoDateParam(to));
    if (!result.ok) {
      dispatch({ type: "setEvents", events: [], error: result.error });
      toast.error(result.error ?? "Could not load events.");
      return;
    }
    dispatch({ type: "setEvents", events: result.data ?? [] });
  }

  function handleNavigate(direction: 1 | -1) {
    const nextAnchor = stepAnchor(view, anchor, direction);
    void setDateParam(nextAnchor.toISOString());
    void refetch(view, nextAnchor);
  }

  function handleToday() {
    const now = new Date();
    void setDateParam(now.toISOString());
    void refetch(view, now);
  }

  function handleViewChange(nextView: CalendarView) {
    void setView(nextView);
    void refetch(nextView, anchor);
  }

  function handleToggleLayer(layer: CalendarLayer) {
    const next = activeLayers.includes(layer) ? activeLayers.filter((l) => l !== layer) : [...activeLayers, layer];
    void setActiveLayers(next);
  }

  function handleNewEvent() {
    if (view === "day" || view === "week") {
      const now = new Date();
      dispatch({ type: "startCreateSlot", day: startOfDay(anchor).toISOString(), minutes: snapMinutes(minutesSinceMidnight(now)) });
      return;
    }
    if (view === "agenda") void setView(CALENDAR_VIEW.MONTH);
    dispatch({ type: "startCreateDay", day: startOfDay(anchor).toISOString() });
  }

  async function commitCreate(title: string, start: Date, end: Date, isTask: boolean) {
    const result = await createEventAction({
      event_type: isTask ? "task" : "custom",
      title,
      starts_at: start.toISOString(),
      ends_at: end.toISOString(),
      visibility: "private",
    });
    dispatch({ type: "clearInteraction" });
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Could not create event.");
      return;
    }
    dispatch({ type: "patchEvent", event: result.data });
  }

  async function handleEventDropOnDay(eventId: string, day: Date) {
    const event = state.events.find((e) => e.id === eventId);
    if (!event) return;
    const start = new Date(event.starts_at);
    const end = new Date(event.ends_at ?? event.starts_at);
    const durationMs = end.getTime() - start.getTime();
    const newStart = new Date(day);
    newStart.setHours(start.getHours(), start.getMinutes(), 0, 0);
    const newEnd = new Date(newStart.getTime() + durationMs);
    const result = await updateEventAction(eventId, { starts_at: newStart.toISOString(), ends_at: newEnd.toISOString() });
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Could not move event.");
      return;
    }
    dispatch({ type: "patchEvent", event: result.data });
  }

  async function handleEventDropOnSlot(eventId: string, newStart: Date) {
    const event = state.events.find((e) => e.id === eventId);
    if (!event) return;
    const durationMs = new Date(event.ends_at ?? event.starts_at).getTime() - new Date(event.starts_at).getTime();
    const newEnd = new Date(newStart.getTime() + durationMs);
    const result = await updateEventAction(eventId, { starts_at: newStart.toISOString(), ends_at: newEnd.toISOString() });
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Could not move event.");
      return;
    }
    dispatch({ type: "patchEvent", event: result.data });
  }

  async function handleToggleComplete(eventId: string, completed: boolean) {
    const result = await setEventCompletedAction(eventId, completed);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Could not update task.");
      return;
    }
    dispatch({ type: "patchEvent", event: result.data });
  }

  async function handleResizeCommit(eventId: string, newEnd: Date) {
    dispatch({ type: "clearInteraction" });
    const result = await updateEventAction(eventId, { ends_at: newEnd.toISOString() });
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Could not resize event.");
      return;
    }
    dispatch({ type: "patchEvent", event: result.data });
  }

  const visibleEvents = state.events
    .filter((ev) => activeLayers.some((l) => layerMatches(l, ev, currentUserId)))
    .filter(
      (ev) =>
        !search ||
        ev.title.toLowerCase().includes(search.toLowerCase()) ||
        (ev.notes ?? "").toLowerCase().includes(search.toLowerCase()),
    );

  const selectedEvent = selectedEventId ? state.events.find((e) => e.id === selectedEventId) ?? null : null;

  async function handleExportIcs() {
    // Open the tab synchronously, in the same tick as the click, then
    // navigate it once the token URL resolves — window.open() called after
    // an await has crossed the async gap and loses the click's user-gesture
    // status, so popup blockers silently swallow it in most browsers.
    const tab = window.open("", "_blank");
    const result = await getIcsFeedUrlAction();
    if (!result.ok || !result.data) {
      tab?.close();
      toast.error(result.error ?? "Could not create a feed link.");
      return;
    }
    if (tab) tab.location.href = result.data;
  }

  if (selectedEvent && detailFetchedForRef.current !== selectedEvent.id) {
    detailFetchedForRef.current = selectedEvent.id;
    dispatch({ type: "setEventDetail", detail: null });
    void getEventAction(selectedEvent.id).then((result) => {
      if (result.ok && result.data) dispatch({ type: "setEventDetail", detail: result.data });
    });
  }

  const resizePreview =
    state.interaction.kind === "resizing"
      ? { eventId: state.interaction.eventId, deltaMinutes: state.interaction.deltaMinutes }
      : null;
  const creatingDay = state.interaction.kind === "creatingDay" ? new Date(state.interaction.day) : null;
  const creatingSlot =
    state.interaction.kind === "creatingSlot"
      ? { day: new Date(state.interaction.day), minutes: state.interaction.minutes }
      : null;

  return (
    <div className="flex flex-col gap-4">
      <CalendarToolbar
        activeLayers={activeLayers}
        rangeLabel={formatRangeLabel(view, anchor)}
        search={search}
        view={view}
        onExportIcs={() => void handleExportIcs()}
        onNavigate={handleNavigate}
        onNewEvent={handleNewEvent}
        onSearchChange={(value) => void setSearch(value || null)}
        onToday={handleToday}
        onToggleLayer={handleToggleLayer}
        onViewChange={handleViewChange}
      />

      {view === "month" && (
        <MonthView
          anchor={anchor}
          creatingDay={creatingDay}
          currentUserId={currentUserId}
          events={visibleEvents}
          onCreateCancel={() => dispatch({ type: "clearInteraction" })}
          onCreateSubmit={(title, start, end, isTask) => void commitCreate(title, start, end, isTask)}
          onDayClick={(day) => dispatch({ type: "startCreateDay", day: day.toISOString() })}
          onEventClick={handleEventClick}
          onEventDropOnDay={(eventId, day) => void handleEventDropOnDay(eventId, day)}
        />
      )}

      {(view === "week" || view === "day") && (
        <TimeGridView
          creatingSlot={creatingSlot}
          currentUserId={currentUserId}
          days={view === "day" ? [anchor] : getWeekDays(anchor)}
          events={visibleEvents}
          resizePreview={resizePreview}
          onCreateCancel={() => dispatch({ type: "clearInteraction" })}
          onCreateSubmit={(title, start, end, isTask) => void commitCreate(title, start, end, isTask)}
          onEventClick={handleEventClick}
          onEventDropOnSlot={(eventId, start) => void handleEventDropOnSlot(eventId, start)}
          onResizeCommit={(eventId, newEnd) => void handleResizeCommit(eventId, newEnd)}
          onResizeMove={(deltaMinutes) => dispatch({ type: "updateResize", deltaMinutes })}
          onResizeStart={(eventId) => dispatch({ type: "startResize", eventId })}
          onSlotClick={(start) => dispatch({ type: "startCreateSlot", day: startOfDay(start).toISOString(), minutes: minutesSinceMidnight(start) })}
        />
      )}

      {view === "agenda" && (
        <AgendaView
          anchor={anchor}
          currentUserId={currentUserId}
          events={visibleEvents}
          onEventClick={(id) => void setSelectedEventId(id)}
          onToggleComplete={(id, completed) => void handleToggleComplete(id, completed)}
        />
      )}

      {selectedEvent && (
        <EventPanel
          attendees={state.eventDetail?.id === selectedEvent.id ? state.eventDetail.attendees : null}
          currentUserId={currentUserId}
          event={selectedEvent}
          key={selectedEvent.id}
          open={Boolean(selectedEvent)}
          pendingInvites={state.eventDetail?.id === selectedEvent.id ? state.eventDetail.pending_invites : null}
          onAttendeeChanged={(attendee) => dispatch({ type: "patchAttendee", attendee })}
          onEventChanged={(event) => dispatch({ type: "patchEvent", event })}
          onInvited={(invite) => dispatch({ type: "addPendingInvite", invite })}
          onOpenChange={(open) => {
            if (!open) void setSelectedEventId(null);
          }}
          onRefetchNeeded={() => void refetch(view, anchor)}
        />
      )}
    </div>
  );
}
