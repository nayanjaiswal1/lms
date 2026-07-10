"use client";

import * as React from "react";
import {
  PX_PER_HOUR,
  dateAtMinutes,
  isSameDay,
  minutesSinceMidnight,
  snapMinutes,
  startOfDay,
} from "@/app/(app)/calendar/calendar-math";
import { EventBlock, primaryLayerFor } from "@/app/(app)/calendar/event-block";
import { QuickCreateSlot } from "@/app/(app)/calendar/quick-create-slot";
import { Popover, PopoverAnchor, PopoverContent } from "@/components/ui/popover";
import type { CalendarEvent } from "@/lib/calendar/types";

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
  onCreateSubmit: (title: string, start: Date, end: Date, isTask: boolean) => void;
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
  const columns = `4rem repeat(${days.length}, minmax(0, 1fr))`;

  return (
    <div className="flex flex-col overflow-hidden rounded-lg border border-border">
      {/* eslint-disable-next-line no-restricted-syntax -- column count varies with view (1 day vs 7-day week), not expressible as a static token */}
      <div className="grid border-b border-border" style={{ gridTemplateColumns: columns }}>
        <div className="border-r border-border" />
        {days.map((day) => {
          // Anchored here (the day header) rather than at the clicked slot inside
          // the scrollable grid below — that scrolls independently of the page, so
          // a popover anchored to a point inside it would scroll out of view (and
          // Radix would float it to wherever that now off-screen point maps to)
          // every time the user scrolled the day/week grid while creating.
          const isCreatingHere = Boolean(creatingSlot && isSameDay(creatingSlot.day, day));
          return (
            <Popover key={day.toISOString()} open={isCreatingHere} onOpenChange={(open) => !open && onCreateCancel()}>
              <PopoverAnchor asChild>
                <div className="border-r border-border px-2 py-1.5 text-center last:border-r-0">
                  <p className="text-xs text-muted-foreground">{day.toLocaleDateString(undefined, { weekday: "short" })}</p>
                  <p className="text-sm font-semibold tabular-nums">{day.getDate()}</p>
                </div>
              </PopoverAnchor>
              {isCreatingHere && creatingSlot && (
                <PopoverContent align="center" className="w-80" side="bottom" onClick={(e) => e.stopPropagation()}>
                  <QuickCreateSlot
                    defaultEnd={dateAtMinutes(startOfDay(day), creatingSlot.minutes + 30)}
                    defaultStart={dateAtMinutes(startOfDay(day), creatingSlot.minutes)}
                    onCancel={onCreateCancel}
                    onCreate={onCreateSubmit}
                  />
                </PopoverContent>
              )}
            </Popover>
          );
        })}
      </div>

      {allDayEvents.length > 0 && (
        // eslint-disable-next-line no-restricted-syntax -- column count varies with view, not expressible as a static token
        <div className="grid border-b border-border bg-muted/40" style={{ gridTemplateColumns: columns }}>
          <div className="border-r border-border px-2 py-1 text-xs text-muted-foreground">All day</div>
          {days.map((day) => (
            <div className="flex flex-col gap-0.5 border-r border-border p-1 last:border-r-0" key={day.toISOString()}>
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

      <div className="relative h-[70vh] overflow-y-auto">
        {/* eslint-disable-next-line no-restricted-syntax -- column count and total-day height are computed from view state, not expressible as static tokens */}
        <div className="grid" style={{ gridTemplateColumns: columns, height: `${24 * PX_PER_HOUR}px` }}>
          <div className="relative border-r border-border">
            {HOURS.map((h) => (
              <div
                key={h}
                className="absolute inset-x-0 -translate-y-1/2 pr-2 text-right text-xs text-muted-foreground"
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
                className="relative border-r border-border last:border-r-0"
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
                  <div className="absolute inset-x-0 border-t border-border/60" key={h} style={{ top: `${h * PX_PER_HOUR}px` }} />
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
                      variant="time"
                      onClick={() => onEventClick(ev.id)}
                      onDragStart={(e) => {
                        e.dataTransfer.setData("text/calendar-event-id", ev.id);
                        e.dataTransfer.effectAllowed = "move";
                      }}
                      resizeHandlers={makeResizeHandlers(ev.id, end, dayStart)}
                      // eslint-disable-next-line no-restricted-syntax -- computed pixel position/height is inherently dynamic, no token can express it
                      style={{ top: `${top}px`, height: `${Math.max(20, height)}px` }}
                    />
                  );
                })}

                {creatingSlot && isSameDay(creatingSlot.day, day) && (
                  <div
                    className="absolute inset-x-0.5 h-8 rounded-md border border-primary bg-primary/10"
                    // eslint-disable-next-line no-restricted-syntax -- computed pixel position mirrors the clicked slot, no token can express it
                    style={{ top: `${(creatingSlot.minutes / 60) * PX_PER_HOUR}px` }}
                  />
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
