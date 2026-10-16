"use client";

import { getMonthGridDays, isSameDay } from "@/app/(app)/calendar/calendar-math";
import { AgendaDayGroup } from "@/app/(app)/calendar/agenda-day-group";
import { EventBlock, layerMetaFor, primaryLayerFor } from "@/app/(app)/calendar/event-block";
import { EnhancedQuickCreate } from "@/app/(app)/calendar/enhanced-quick-create";
import { useNow } from "@/app/(app)/calendar/use-now";
import { Popover, PopoverAnchor, PopoverContent } from "@/components/ui/popover";
import type { CalendarEvent, CalendarEventPriority } from "@/lib/calendar/types";
import { cn } from "@/lib/utils";

const WEEKDAY_LABELS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MAX_CHIPS = 3;

interface MonthViewProps {
  anchor: Date;
  events: CalendarEvent[];
  currentUserId: string;
  creatingDay: Date | null;
  onDayClick: (day: Date) => void;
  onEventClick: (eventId: string) => void;
  onEventDropOnDay: (eventId: string, day: Date) => void;
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
  const now = useNow();
  const days = getMonthGridDays(anchor).map((day) => ({
    day,
    inMonth: day.getMonth() === anchor.getMonth(),
    isToday: Boolean(now && isSameDay(day, now)),
    dayEvents: events
      .filter((ev) => isSameDay(new Date(ev.starts_at), day))
      .sort((a, b) => a.starts_at.localeCompare(b.starts_at)),
  }));
  const monthDaysWithEvents = days.filter((d) => d.inMonth && d.dayEvents.length > 0);

  return (
    <div className="flex flex-col gap-6">
      <div className="overflow-hidden rounded-lg border border-border bg-border">
        <div className="grid grid-cols-7 gap-px">
          {WEEKDAY_LABELS.map((label) => (
            <div className="bg-muted py-2 text-center text-xs font-medium uppercase text-muted-foreground" key={label}>
              <abbr className="no-underline" title={label}>
                <span className="sm:hidden">{label.charAt(0)}</span>
                <span className="hidden sm:inline">{label}</span>
              </abbr>
            </div>
          ))}
          {days.map(({ day, inMonth, isToday, dayEvents }) => {
            const isCreatingHere = Boolean(creatingDay && isSameDay(creatingDay, day));
            const hidden = dayEvents.length - MAX_CHIPS;
            return (
              <Popover key={day.toISOString()} open={isCreatingHere} onOpenChange={(open) => !open && onCreateCancel()}>
                <PopoverAnchor asChild>
                  <div
                    aria-label={`${day.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })}, ${
                      dayEvents.length === 1 ? "1 event" : `${dayEvents.length} events`
                    }. Press Enter to add an event.`}
                    className={cn(
                      "relative flex min-h-16 cursor-pointer flex-col gap-1 p-1 transition-colors duration-fast ease-smooth sm:min-h-28 sm:p-1.5",
                      inMonth ? "bg-card hover:bg-muted" : "bg-muted",
                    )}
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
                    {/* Tints sit on an overlay: the grid's 1px gutters are the parent's
                        bg-border, so a translucent cell background would bleed it through. */}
                    {(isToday || isCreatingHere) && (
                      <span aria-hidden className={cn("pointer-events-none absolute inset-0", isCreatingHere ? "bg-primary/10" : "bg-primary/5")} />
                    )}
                    {isToday && <span aria-hidden className="absolute inset-x-0 top-0 h-0.5 bg-primary" />}
                    <span
                      className={cn(
                        "flex h-6 w-6 items-center justify-center self-center rounded-full text-xs font-medium tabular-nums sm:self-start",
                        isToday ? "bg-primary font-semibold text-primary-foreground" : inMonth ? "text-foreground" : "text-muted-foreground",
                      )}
                    >
                      {day.getDate()}
                    </span>

                    {/* Mobile: a dot per event (up to 3) — chips don't fit a 46px column. */}
                    {dayEvents.length > 0 && (
                      <span aria-hidden className="flex items-center justify-center gap-0.5 sm:hidden">
                        {dayEvents.slice(0, MAX_CHIPS).map((ev) => (
                          <span className={cn("h-1.5 w-1.5 rounded-full", layerMetaFor(primaryLayerFor(ev, currentUserId)).swatchClassName)} key={ev.id} />
                        ))}
                      </span>
                    )}

                    <div className="hidden min-w-0 flex-col gap-0.5 sm:flex">
                      {dayEvents.slice(0, MAX_CHIPS).map((ev) => (
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
                      {hidden > 0 && <span className="px-1.5 text-xs font-medium text-muted-foreground">+{hidden} more</span>}
                    </div>
                  </div>
                </PopoverAnchor>
                {isCreatingHere && (
                  <PopoverContent
                    align="start"
                    className="w-96 max-w-[calc(100vw-2rem)]"
                    collisionPadding={16}
                    onClick={(e) => e.stopPropagation()}
                  >
                    <EnhancedQuickCreate
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
      </div>

      {/* Mobile: the grid only shows dots, so the month's events are listed
          underneath as tappable rows. */}
      <div className="flex flex-col gap-4 sm:hidden">
        {monthDaysWithEvents.length === 0 ? (
          <p className="text-center text-sm text-muted-foreground">Nothing scheduled this month. Tap a day to add an event.</p>
        ) : (
          monthDaysWithEvents.map(({ day, dayEvents, isToday }) => (
            <AgendaDayGroup
              currentUserId={currentUserId}
              day={day}
              events={dayEvents}
              isToday={isToday}
              key={day.toISOString()}
              onEventClick={onEventClick}
            />
          ))
        )}
      </div>
    </div>
  );
}
