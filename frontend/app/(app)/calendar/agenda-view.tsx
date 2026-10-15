"use client";

import { CalendarX2 } from "lucide-react";
import { isSameDay } from "@/app/(app)/calendar/calendar-math";
import { AgendaDayGroup } from "@/app/(app)/calendar/agenda-day-group";
import { useNow } from "@/app/(app)/calendar/use-now";
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
  const now = useNow();
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
      <div className="empty-state rounded-lg border border-dashed border-border">
        <CalendarX2 aria-hidden className="empty-state-icon" />
        <div className="flex flex-col gap-1">
          <p className="font-medium text-foreground">{tasksOnly ? "No tasks in the next 30 days" : "Nothing scheduled in the next 30 days"}</p>
          <p className="text-sm">Use New event to block out time, or step forward to look further ahead.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      {groups.map(({ day, dayEvents }) => (
        <AgendaDayGroup
          currentUserId={currentUserId}
          day={day}
          events={dayEvents}
          isToday={Boolean(now && isSameDay(day, now))}
          key={day.toISOString()}
          onEventClick={onEventClick}
          onToggleComplete={onToggleComplete}
        />
      ))}
    </div>
  );
}
