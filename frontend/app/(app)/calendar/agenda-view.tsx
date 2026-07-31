"use client";

import { CalendarX2 } from "lucide-react";
import { isSameDay } from "@/app/(app)/calendar/calendar-math";
import { EventBlock, primaryLayerFor } from "@/app/(app)/calendar/event-block";
import { CALENDAR_PRIORITY_RANK, CALENDAR_PRIORITY_UNSET_RANK } from "@/lib/calendar/types";
import type { CalendarEvent } from "@/lib/calendar/types";

interface AgendaViewProps {
  anchor: Date;
  events: CalendarEvent[];
  currentUserId: string;
  // "My Tasks" mode — filters to event_type: "task" and sorts each day's
  // rows by priority (urgent first) ahead of start time, instead of the
  // default chronological-only agenda ordering.
  tasksOnly?: boolean;
  onEventClick: (eventId: string) => void;
  onToggleComplete: (eventId: string, completed: boolean) => void;
}

function taskSort(a: CalendarEvent, b: CalendarEvent): number {
  const rankA = a.priority ? CALENDAR_PRIORITY_RANK[a.priority] : CALENDAR_PRIORITY_UNSET_RANK;
  const rankB = b.priority ? CALENDAR_PRIORITY_RANK[b.priority] : CALENDAR_PRIORITY_UNSET_RANK;
  return rankA !== rankB ? rankA - rankB : a.starts_at.localeCompare(b.starts_at);
}

export function AgendaView({ anchor, events, currentUserId, tasksOnly = false, onEventClick, onToggleComplete }: AgendaViewProps) {
  const days = Array.from({ length: 30 }, (_, i) => {
    const d = new Date(anchor);
    d.setDate(d.getDate() + i);
    return d;
  });

  const scopedEvents = tasksOnly ? events.filter((ev) => ev.event_type === "task") : events;

  const groups = days
    .map((day) => ({
      day,
      dayEvents: scopedEvents
        .filter((ev) => isSameDay(new Date(ev.starts_at), day))
        .sort(tasksOnly ? taskSort : (a, b) => a.starts_at.localeCompare(b.starts_at)),
    }))
    .filter((g) => g.dayEvents.length > 0);

  if (groups.length === 0) {
    return (
      <div className="empty-state py-16">
        <CalendarX2 aria-hidden className="h-10 w-10 text-muted-foreground" />
        <p className="mt-3 text-sm text-muted-foreground">
          {tasksOnly ? "No tasks in the next 30 days." : "No events in the next 30 days."}
        </p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      {groups.map(({ day, dayEvents }) => (
        <div className="flex flex-col gap-2" key={day.toISOString()}>
          <h3 className="text-sm font-semibold text-muted-foreground">
            {day.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })}
          </h3>
          <div className="flex flex-col gap-1.5 rounded-lg border border-border p-2">
            {dayEvents.map((ev) => (
              <EventBlock
                event={ev}
                key={ev.id}
                layer={primaryLayerFor(ev, currentUserId)}
                variant="agenda"
                onClick={() => onEventClick(ev.id)}
                onToggleComplete={
                  ev.event_type === "task" ? (completed) => onToggleComplete(ev.id, completed) : undefined
                }
              />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}
