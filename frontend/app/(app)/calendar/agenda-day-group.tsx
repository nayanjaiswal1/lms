"use client";

import { EventBlock, primaryLayerFor } from "@/app/(app)/calendar/event-block";
import type { CalendarEvent } from "@/lib/calendar/types";
import { cn } from "@/lib/utils";

interface AgendaDayGroupProps {
  day: Date;
  events: CalendarEvent[];
  currentUserId: string;
  isToday: boolean;
  onEventClick: (eventId: string) => void;
  onToggleComplete?: (eventId: string, completed: boolean) => void;
}

/** One day of a list view: a tear-off date stub on the left, that day's rows on the right. */
export function AgendaDayGroup({ day, events, currentUserId, isToday, onEventClick, onToggleComplete }: AgendaDayGroupProps) {
  const headingId = `agenda-${day.toISOString()}`;
  return (
    <section aria-labelledby={headingId} className="flex gap-3 sm:gap-4">
      <div
        className={cn(
          "flex w-12 shrink-0 flex-col items-center self-start rounded-lg border py-2 sm:w-14",
          isToday ? "border-primary bg-primary text-primary-foreground" : "border-border bg-card",
        )}
        id={headingId}
      >
        <span className={cn("text-xs font-medium uppercase", !isToday && "text-muted-foreground")}>
          {day.toLocaleDateString(undefined, { weekday: "short" })}
        </span>
        <span className="text-xl font-semibold tabular-nums">{day.getDate()}</span>
        <span className="sr-only">{day.toLocaleDateString(undefined, { month: "long", year: "numeric" })}</span>
        {isToday && <span className="text-xs font-medium">Today</span>}
      </div>
      <div className="flex min-w-0 flex-1 flex-col divide-y divide-border rounded-lg border border-border bg-card p-1">
        {events.map((ev) => (
          <EventBlock
            event={ev}
            key={ev.id}
            layer={primaryLayerFor(ev, currentUserId)}
            variant="agenda"
            onClick={() => onEventClick(ev.id)}
            onToggleComplete={
              onToggleComplete && ev.event_type === "task" ? (completed) => onToggleComplete(ev.id, completed) : undefined
            }
          />
        ))}
      </div>
    </section>
  );
}
