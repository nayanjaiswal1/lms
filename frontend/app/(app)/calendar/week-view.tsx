"use client";

import * as React from "react";
import { ChevronLeft, ChevronRight, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { EventBlock, primaryLayerFor } from "@/app/(app)/calendar/event-block";
import { formatRangeLabel, getWeekDays, isSameDay } from "@/app/(app)/calendar/calendar-math";
import { useNow } from "@/app/(app)/calendar/use-now";
import { CALENDAR_LAYER_OPTIONS } from "@/lib/calendar/types";
import type { CalendarEvent } from "@/lib/calendar/types";
import { cn } from "@/lib/utils";

interface WeekViewProps {
  anchor: Date;
  events: CalendarEvent[];
  currentUserId: string;
  onDateSelect: (date: Date, time: Date) => void;
  onEventClick: (eventId: string) => void;
  onNavigate: (direction: "prev" | "next") => void;
}

const HOURS = Array.from({ length: 24 }, (_, i) => i);
const DAY_LABELS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

export function WeekView({
  anchor,
  events,
  currentUserId,
  onDateSelect,
  onEventClick,
  onNavigate,
}: WeekViewProps) {
  const now = useNow();
  const days = getWeekDays(anchor);

  return (
    <div className="space-y-4">
      <div className="flex-between gap-2">
        <h2 aria-live="polite" className="subsection-title min-w-0 truncate">{formatRangeLabel("week", anchor)}</h2>
        <div className="flex shrink-0 gap-2">
          <Button aria-label="Previous week" className="touch-target-dense" size="sm" variant="outline" onClick={() => onNavigate("prev")}>
            <ChevronLeft aria-hidden />
          </Button>
          <Button aria-label="Next week" className="touch-target-dense" size="sm" variant="outline" onClick={() => onNavigate("next")}>
            <ChevronRight aria-hidden />
          </Button>
        </div>
      </div>

      <div className="overflow-hidden rounded-lg border border-border bg-card">
        {/* eslint-disable-next-line no-restricted-syntax -- 7-day grid needs a fixed time-gutter column plus 7 shrinkable day columns, not expressible as a static token */}
        <div className="grid" style={{ gridTemplateColumns: "3rem repeat(7, minmax(0, 1fr))" }}>
          <div className="border-r border-border bg-muted/50" />

          {days.map((day, i) => {
            const isToday = Boolean(now && isSameDay(day, now));
            return (
              <div
                aria-current={isToday ? "date" : undefined}
                className="flex min-w-0 flex-col items-center gap-0.5 border-r border-border bg-muted/30 px-0.5 py-2 last:border-r-0"
                key={i}
              >
                <span className={cn("text-xs font-medium uppercase", isToday ? "text-primary" : "text-muted-foreground")}>{DAY_LABELS[i]}</span>
                <span className={cn("flex h-7 w-7 items-center justify-center rounded-full text-sm font-semibold tabular-nums", isToday && "bg-primary text-primary-foreground")}>
                  {day.getDate()}
                </span>
              </div>
            );
          })}

          {HOURS.map((hour) => (
            <React.Fragment key={hour}>
              <div className="border-b border-r border-border bg-muted/50 py-1 pr-1.5 text-right text-xs tabular-nums text-muted-foreground">
                {String(hour).padStart(2, "0")}:00
              </div>

              {days.map((day, dayIdx) => {
                const slotEvents = events.filter((e) => {
                  const start = new Date(e.starts_at);
                  return isSameDay(start, day) && start.getHours() === hour;
                });

                return (
                  <div
                    aria-label={`Create an event on ${day.toDateString()} at ${hour}:00`}
                    className="group relative flex h-12 min-w-0 cursor-pointer flex-col gap-0.5 overflow-hidden border-b border-r border-border/50 bg-background p-0.5 transition-colors duration-fast ease-smooth hover:bg-muted/50"
                    key={`${dayIdx}-${hour}`}
                    role="button"
                    tabIndex={0}
                    onClick={() => {
                      const slotStart = new Date(day);
                      slotStart.setHours(hour, 0, 0, 0);
                      onDateSelect(day, slotStart);
                    }}
                    onKeyDown={(e) => {
                      if (e.key === "Enter" || e.key === " ") {
                        e.preventDefault();
                        const slotStart = new Date(day);
                        slotStart.setHours(hour, 0, 0, 0);
                        onDateSelect(day, slotStart);
                      }
                    }}
                  >
                    <div aria-hidden className="pointer-events-none absolute inset-0 flex items-center justify-center opacity-0 transition-opacity duration-fast group-hover:opacity-100">
                      <Plus className="h-4 w-4 text-muted-foreground" />
                    </div>

                    {slotEvents.map((event) => (
                      <EventBlock
                        event={event}
                        key={event.id}
                        layer={primaryLayerFor(event, currentUserId)}
                        variant="month"
                        onClick={() => onEventClick(event.id)}
                      />
                    ))}
                  </div>
                );
              })}
            </React.Fragment>
          ))}
        </div>
      </div>

      <ul aria-label="Legend" className="flex flex-wrap gap-x-4 gap-y-2 text-xs">
        {CALENDAR_LAYER_OPTIONS.map((layer) => (
          <li className="flex items-center gap-2" key={layer.value}>
            <span aria-hidden className={cn("h-2.5 w-2.5 rounded-full", layer.swatchClassName)} />
            <span className="text-muted-foreground">{layer.label}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
