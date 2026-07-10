"use client";

import { getMonthGridDays, isSameDay } from "@/app/(app)/calendar/calendar-math";
import { EventBlock, primaryLayerFor } from "@/app/(app)/calendar/event-block";
import { QuickCreateSlot } from "@/app/(app)/calendar/quick-create-slot";
import { Popover, PopoverAnchor, PopoverContent } from "@/components/ui/popover";
import type { CalendarEvent } from "@/lib/calendar/types";

const WEEKDAY_LABELS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

interface MonthViewProps {
  anchor: Date;
  events: CalendarEvent[];
  currentUserId: string;
  creatingDay: Date | null;
  onDayClick: (day: Date) => void;
  onEventClick: (eventId: string) => void;
  onEventDropOnDay: (eventId: string, day: Date) => void;
  onCreateSubmit: (title: string, start: Date, end: Date, isTask: boolean) => void;
  onCreateCancel: () => void;
}

export function MonthView({
  anchor,
  events,
  currentUserId,
  creatingDay,
  onDayClick,
  onEventClick,
  onEventDropOnDay,
  onCreateSubmit,
  onCreateCancel,
}: MonthViewProps) {
  const days = getMonthGridDays(anchor);
  const today = new Date();

  return (
    <div className="grid grid-cols-7 gap-px overflow-hidden rounded-lg border border-border bg-border">
      {WEEKDAY_LABELS.map((label) => (
        <div className="bg-muted px-2 py-1.5 text-center text-xs font-medium text-muted-foreground" key={label}>
          {label}
        </div>
      ))}
      {days.map((day) => {
        const inMonth = day.getMonth() === anchor.getMonth();
        const dayEvents = events
          .filter((ev) => isSameDay(new Date(ev.starts_at), day))
          .sort((a, b) => a.starts_at.localeCompare(b.starts_at));
        const isCreatingHere = Boolean(creatingDay && isSameDay(creatingDay, day));

        return (
          <Popover key={day.toISOString()} open={isCreatingHere} onOpenChange={(open) => !open && onCreateCancel()}>
            <PopoverAnchor asChild>
              <div
                className={`flex min-h-24 flex-col gap-1 bg-card p-1.5 ${inMonth ? "" : "opacity-40"}`}
                role="button"
                tabIndex={0}
                onClick={() => onDayClick(day)}
                onDragOver={(e) => e.preventDefault()}
                onDrop={(e) => {
                  e.preventDefault();
                  const eventId = e.dataTransfer.getData("text/calendar-event-id");
                  if (eventId) onEventDropOnDay(eventId, day);
                }}
                onKeyDown={(e) => {
                  if (e.key === "Enter" || e.key === " ") {
                    e.preventDefault();
                    onDayClick(day);
                  }
                }}
              >
                <span
                  className={`w-fit rounded-pill px-1.5 text-xs font-medium tabular-nums ${
                    isSameDay(day, today) ? "bg-primary text-primary-foreground" : "text-muted-foreground"
                  }`}
                >
                  {day.getDate()}
                </span>
                <div className="flex flex-col gap-0.5">
                  {dayEvents.slice(0, 3).map((ev) => (
                    <EventBlock
                      draggable
                      event={ev}
                      key={ev.id}
                      layer={primaryLayerFor(ev, currentUserId)}
                      variant="month"
                      onClick={() => onEventClick(ev.id)}
                      onDragStart={(e) => {
                        e.dataTransfer.setData("text/calendar-event-id", ev.id);
                        e.dataTransfer.effectAllowed = "move";
                      }}
                    />
                  ))}
                  {dayEvents.length > 3 && (
                    <span className="px-1 text-xs text-muted-foreground">+{dayEvents.length - 3} more</span>
                  )}
                </div>
              </div>
            </PopoverAnchor>
            {isCreatingHere && (
              <PopoverContent align="start" className="w-80" onClick={(e) => e.stopPropagation()}>
                <QuickCreateSlot
                  defaultEnd={new Date(day.getFullYear(), day.getMonth(), day.getDate(), 9, 30)}
                  defaultStart={new Date(day.getFullYear(), day.getMonth(), day.getDate(), 9, 0)}
                  onCancel={onCreateCancel}
                  onCreate={onCreateSubmit}
                />
              </PopoverContent>
            )}
          </Popover>
        );
      })}
    </div>
  );
}
