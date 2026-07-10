"use client";

import { CalendarX2 } from "lucide-react";
import { isSameDay } from "@/app/(app)/calendar/calendar-math";
import { EventBlock, primaryLayerFor } from "@/app/(app)/calendar/event-block";
import type { CalendarEvent } from "@/lib/calendar/types";

interface AgendaViewProps {
  anchor: Date;
  events: CalendarEvent[];
  currentUserId: string;
  onEventClick: (eventId: string) => void;
  onToggleComplete: (eventId: string, completed: boolean) => void;
}

export function AgendaView({ anchor, events, currentUserId, onEventClick, onToggleComplete }: AgendaViewProps) {
  const days = Array.from({ length: 30 }, (_, i) => {
    const d = new Date(anchor);
    d.setDate(d.getDate() + i);
    return d;
  });

  const groups = days
    .map((day) => ({
      day,
      dayEvents: events
        .filter((ev) => isSameDay(new Date(ev.starts_at), day))
        .sort((a, b) => a.starts_at.localeCompare(b.starts_at)),
    }))
    .filter((g) => g.dayEvents.length > 0);

  if (groups.length === 0) {
    return (
      <div className="empty-state py-16">
        <CalendarX2 aria-hidden className="h-10 w-10 text-muted-foreground" />
        <p className="mt-3 text-sm text-muted-foreground">No events in the next 30 days.</p>
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
