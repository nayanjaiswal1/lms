"use client";

import * as React from "react";
import {
  PX_PER_HOUR,
  dateAtMinutes,
  formatTimeLabel,
  isSameDay,
  minutesSinceMidnight,
  snapMinutes,
  startOfDay,
} from "@/app/(app)/calendar/calendar-math";
import { EventBlock, primaryLayerFor } from "@/app/(app)/calendar/event-block";
import { TimeGridHeader } from "@/app/(app)/calendar/time-grid-header";
import { useNow } from "@/app/(app)/calendar/use-now";
import type { CalendarEvent, CalendarEventPriority } from "@/lib/calendar/types";
import { cn } from "@/lib/utils";

const HOURS = Array.from({ length: 24 }, (_, h) => h);

interface ResizePreview {
  eventId: string;
  deltaMinutes: number;
}

interface CreatingSlot {
  day: Date;
  minutes: number;
}

interface TimeGridViewProps {
  days: Date[];
  events: CalendarEvent[];
  currentUserId: string;
  resizePreview: ResizePreview | null;
  creatingSlot: CreatingSlot | null;
  onEventClick: (eventId: string) => void;
  onSlotClick: (start: Date) => void;
  onEventDropOnSlot: (eventId: string, start: Date) => void;
  onResizeStart: (eventId: string) => void;
  onResizeMove: (deltaMinutes: number) => void;
  onResizeCommit: (eventId: string, newEnd: Date) => void;
  onCreateSubmit: (
    title: string,
    start: Date,
    end: Date,
    isTask: boolean,
    notes?: string,
    priority?: CalendarEventPriority,
  ) => void;
  onCreateCancel: () => void;
}

export function TimeGridView({
  days,
  events,
  currentUserId,
  resizePreview,
  creatingSlot,
  onEventClick,
  onSlotClick,
  onEventDropOnSlot,
  onResizeStart,
  onResizeMove,
  onResizeCommit,
  onCreateSubmit,
  onCreateCancel,
}: TimeGridViewProps) {
  // Transient DOM bookkeeping for the in-progress resize gesture — a ref, not
  // state, since only the *commit* needs a re-render (via onResizeMove →
  // parent reducer for the live preview height).
  const resizeOrigin = React.useRef<{ clientY: number; originEndMinutes: number; day: Date } | null>(null);
  const now = useNow();

  // Callback ref (not an effect): on mount, scroll so the hour before "now"
  // sits at the top instead of opening on midnight.
  const scrollToNow = React.useCallback((el: HTMLDivElement | null) => {
    if (el) el.scrollTop = Math.max(0, (minutesSinceMidnight(new Date()) / 60 - 1) * PX_PER_HOUR);
  }, []);

  function minutesFromPointer(container: HTMLElement, clientY: number): number {
    const rect = container.getBoundingClientRect();
    return snapMinutes(((clientY - rect.top) / PX_PER_HOUR) * 60);
  }

  function makeResizeHandlers(eventId: string, end: Date, dayStart: Date) {
    return {
      onPointerDown: (e: React.PointerEvent) => {
        resizeOrigin.current = { clientY: e.clientY, originEndMinutes: minutesSinceMidnight(end), day: dayStart };
        onResizeStart(eventId);
      },
      onPointerMove: (e: React.PointerEvent) => {
        if (!resizeOrigin.current) return;
        onResizeMove(snapMinutes(((e.clientY - resizeOrigin.current.clientY) / PX_PER_HOUR) * 60));
      },
      onPointerUp: (e: React.PointerEvent) => {
        if (!resizeOrigin.current) return;
        const deltaMinutes = snapMinutes(((e.clientY - resizeOrigin.current.clientY) / PX_PER_HOUR) * 60);
        const newEndMinutes = Math.max(15, resizeOrigin.current.originEndMinutes + deltaMinutes);
        onResizeCommit(eventId, dateAtMinutes(resizeOrigin.current.day, newEndMinutes));
        resizeOrigin.current = null;
      },
    };
  }

  const allDayEvents = events.filter((ev) => ev.all_day && days.some((d) => isSameDay(d, new Date(ev.starts_at))));
  const timedEvents = events.filter((ev) => !ev.all_day);
  const columns = `3.5rem repeat(${days.length}, minmax(0, 1fr))`;
  const isToday = (day: Date) => Boolean(now && isSameDay(day, now));
  const nowInRange = days.some(isToday);
  const nowTop = now ? (minutesSinceMidnight(now) / 60) * PX_PER_HOUR : 0;

  return (
    <div className="flex flex-col overflow-hidden rounded-lg border border-border bg-card">
      <TimeGridHeader
        columns={columns}
        creatingSlot={creatingSlot}
        days={days}
        now={now}
        onCreateCancel={onCreateCancel}
        onCreateSubmit={onCreateSubmit}
      />

      {allDayEvents.length > 0 && (
        // eslint-disable-next-line no-restricted-syntax -- column count varies with view, not expressible as a static token
        <div className="grid border-b border-border bg-muted/40" style={{ gridTemplateColumns: columns }}>
          <div className="flex items-center justify-end border-r border-border pr-1.5 text-xs text-muted-foreground">All day</div>
          {days.map((day) => (
            <div className="flex min-w-0 flex-col gap-0.5 border-r border-border p-1 last:border-r-0" key={day.toISOString()}>
              {allDayEvents
                .filter((ev) => isSameDay(new Date(ev.starts_at), day))
                .map((ev) => (
                  <EventBlock
                    event={ev}
                    key={ev.id}
                    layer={primaryLayerFor(ev, currentUserId)}
                    variant="month"
                    onClick={() => onEventClick(ev.id)}
                  />
                ))}
            </div>
          ))}
        </div>
      )}

      <div className="relative h-[70dvh] overflow-y-auto overscroll-contain" ref={scrollToNow}>
        {/* eslint-disable-next-line no-restricted-syntax -- column count and total-day height are computed from view state, not expressible as static tokens */}
        <div className="relative grid" style={{ gridTemplateColumns: columns, height: `${24 * PX_PER_HOUR}px` }}>
          <div className="relative border-r border-border">
            {HOURS.map((h) => (
              <div
                className="absolute inset-x-0 -translate-y-1/2 pr-1.5 text-right text-xs tabular-nums text-muted-foreground"
                key={h}
                // eslint-disable-next-line no-restricted-syntax -- hour marker offset is computed from PX_PER_HOUR, not expressible as a static token
                style={{ top: `${h * PX_PER_HOUR}px` }}
              >
                {h === 0 ? "" : new Date(2000, 0, 1, h).toLocaleTimeString(undefined, { hour: "numeric" })}
              </div>
            ))}
          </div>

          {days.map((day) => {
            const dayStart = startOfDay(day);
            const dayEvents = timedEvents.filter((ev) => isSameDay(new Date(ev.starts_at), day));

            return (
              <div
                aria-label={`Create an event on ${day.toDateString()}`}
                className={cn("relative cursor-pointer border-r border-border last:border-r-0", isToday(day) && "bg-primary/5")}
                key={day.toISOString()}
                role="button"
                tabIndex={0}
                onClick={(e) => {
                  const minutes = minutesFromPointer(e.currentTarget, e.clientY);
                  onSlotClick(dateAtMinutes(dayStart, minutes));
                }}
                onDragOver={(e) => e.preventDefault()}
                onDrop={(e) => {
                  e.preventDefault();
                  const eventId = e.dataTransfer.getData("text/calendar-event-id");
                  if (!eventId) return;
                  const minutes = minutesFromPointer(e.currentTarget, e.clientY);
                  onEventDropOnSlot(eventId, dateAtMinutes(dayStart, minutes));
                }}
                onKeyDown={(e) => {
                  if (e.key === "Enter" || e.key === " ") {
                    e.preventDefault();
                    onSlotClick(dateAtMinutes(dayStart, minutesSinceMidnight(new Date())));
                  }
                }}
              >
                {HOURS.map((h) => (
                  // eslint-disable-next-line no-restricted-syntax -- hour gridline offset is computed from PX_PER_HOUR, not expressible as a static token
                  <div className="absolute inset-x-0 h-14 border-t border-border/70" key={h} style={{ top: `${h * PX_PER_HOUR}px` }}>
                    <div className="absolute inset-x-0 top-1/2 border-t border-dashed border-border/40" />
                  </div>
                ))}

                {dayEvents.map((ev) => {
                  const start = new Date(ev.starts_at);
                  const end = new Date(ev.ends_at ?? ev.starts_at);
                  const startMinutes = minutesSinceMidnight(start);
                  let durationMinutes = Math.max(15, (end.getTime() - start.getTime()) / 60000);
                  if (resizePreview?.eventId === ev.id) {
                    durationMinutes = Math.max(15, durationMinutes + resizePreview.deltaMinutes);
                  }
                  const top = (startMinutes / 60) * PX_PER_HOUR;
                  const height = (durationMinutes / 60) * PX_PER_HOUR;

                  return (
                    <EventBlock
                      draggable
                      event={ev}
                      key={ev.id}
                      layer={primaryLayerFor(ev, currentUserId)}
                      resizeHandlers={makeResizeHandlers(ev.id, end, dayStart)}
                      // eslint-disable-next-line no-restricted-syntax -- computed pixel position/height is inherently dynamic, no token can express it
                      style={{ top: `${top}px`, height: `${Math.max(20, height)}px` }}
                      variant="time"
                      onClick={() => onEventClick(ev.id)}
                      onDragStart={(e) => {
                        e.dataTransfer.setData("text/calendar-event-id", ev.id);
                        e.dataTransfer.effectAllowed = "move";
                      }}
                    />
                  );
                })}

                {creatingSlot && isSameDay(creatingSlot.day, day) && (
                  <div
                    className="absolute inset-x-0.5 flex h-8 items-center rounded-md border border-dashed border-primary bg-primary/10 px-2 text-xs font-medium text-primary"
                    // eslint-disable-next-line no-restricted-syntax -- computed pixel position mirrors the clicked slot, no token can express it
                    style={{ top: `${(creatingSlot.minutes / 60) * PX_PER_HOUR}px` }}
                  >
                    <span className="truncate">New</span>
                  </div>
                )}

                {isToday(day) && (
                  <div
                    aria-hidden
                    className="pointer-events-none absolute inset-x-0 z-raised h-0.5 -translate-y-1/2 bg-primary"
                    // eslint-disable-next-line no-restricted-syntax -- now-line offset is computed from the current minute, no token can express it
                    style={{ top: `${nowTop}px` }}
                  >
                    <span className="absolute -left-1 -top-1 h-2.5 w-2.5 rounded-full bg-primary ring-2 ring-card" />
                  </div>
                )}
              </div>
            );
          })}

          {nowInRange && now && (
            // The "ember line": a faint rule across every day plus a live time
            // pill in the gutter, so the current moment reads at a glance.
            <div
              aria-hidden
              className="pointer-events-none absolute inset-x-0 z-raised -translate-y-1/2"
              // eslint-disable-next-line no-restricted-syntax -- now-line offset is computed from the current minute, no token can express it
              style={{ top: `${nowTop}px` }}
            >
              <div className="absolute left-14 right-0 top-1/2 h-px bg-primary/40" />
              <span className="relative ml-0.5 inline-block rounded-pill bg-primary px-1 text-xs font-semibold tabular-nums text-primary-foreground">
                {formatTimeLabel(now)}
              </span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
