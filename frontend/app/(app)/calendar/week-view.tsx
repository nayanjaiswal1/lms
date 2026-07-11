"use client";

import * as React from "react";
import { ChevronLeft, ChevronRight, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { EventBlock, primaryLayerFor } from "@/app/(app)/calendar/event-block";
import { startOfWeek, addDays, isSameDay } from "@/app/(app)/calendar/calendar-math";
import type { CalendarEvent } from "@/lib/calendar/types";

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
const MONTH_LABELS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function formatDateRange(start: Date, end: Date): string {
  const startMonth = MONTH_LABELS[start.getMonth()];
  const endMonth = MONTH_LABELS[end.getMonth()];
  const startDay = start.getDate();
  const endDay = end.getDate();
  const year = end.getFullYear();

  if (start.getMonth() === end.getMonth()) {
    return `${startMonth} ${startDay} – ${endDay}, ${year}`;
  }
  return `${startMonth} ${startDay} – ${endMonth} ${endDay}, ${year}`;
}

function getEventsForDay(events: CalendarEvent[], day: Date): CalendarEvent[] {
  return events.filter((e) => {
    const eventDay = new Date(e.starts_at);
    return (
      eventDay.getFullYear() === day.getFullYear() &&
      eventDay.getMonth() === day.getMonth() &&
      eventDay.getDate() === day.getDate()
    );
  });
}

function getEventPosition(event: CalendarEvent, dayStart: Date): {
  top: number;
  height: number;
  left: number;
  width: number;
} {
  const start = new Date(event.starts_at);
  const end = event.ends_at ? new Date(event.ends_at) : new Date(start.getTime() + 60 * 60 * 1000);

  const startMinutes = start.getHours() * 60 + start.getMinutes();
  const endMinutes = end.getHours() * 60 + end.getMinutes();
  const durationMinutes = Math.max(endMinutes - startMinutes, 30);

  const pxPerMinute = 48 / 60; // 48px per hour
  const top = startMinutes * pxPerMinute;
  const height = durationMinutes * pxPerMinute;

  return {
    top,
    height,
    left: 0,
    width: 100,
  };
}

export function WeekView({
  anchor,
  events,
  currentUserId,
  onDateSelect,
  onEventClick,
  onNavigate,
}: WeekViewProps) {
  const weekStart = startOfWeek(anchor);
  const days = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));

  return (
    <div className="space-y-4">
      {/* Header with navigation */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold">
            {formatDateRange(weekStart, addDays(weekStart, 6))}
          </h2>
        </div>
        <div className="flex gap-2">
          <Button size="sm" variant="outline" onClick={() => onNavigate("prev")}>
            <ChevronLeft className="h-4 w-4" />
          </Button>
          <Button size="sm" variant="outline" onClick={() => onNavigate("next")}>
            <ChevronRight className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* Week grid */}
      <div className="rounded-lg border border-border bg-card overflow-x-auto">
        <div className="grid" style={{ gridTemplateColumns: "60px repeat(7, 1fr)" }}>
          {/* Time column header */}
          <div className="sticky left-0 z-10 bg-muted/50 border-r border-border" />

          {/* Day headers */}
          {days.map((day, i) => {
            const today = new Date();
            const isToday = isSameDay(day, today);
            return (
              <div
                key={i}
                className={`border-r border-border p-3 text-center ${isToday ? "bg-primary/10" : "bg-muted/30"}`}
              >
                <div className="text-xs font-medium text-muted-foreground">{DAY_LABELS[i]}</div>
                <div className={`text-sm font-semibold ${isToday ? "text-primary" : ""}`}>{day.getDate()}</div>
              </div>
            );
          })}

          {/* Time slots */}
          {HOURS.map((hour) => (
            <React.Fragment key={hour}>
              {/* Time label */}
              <div className="sticky left-0 z-10 border-r border-b border-border bg-muted/50 px-2 py-2 text-right text-xs text-muted-foreground">
                {String(hour).padStart(2, "0")}:00
              </div>

              {/* Day slots */}
              {days.map((day, dayIdx) => {
                const dayEvents = getEventsForDay(events, day);
                const slotEvents = dayEvents.filter((e) => {
                  const eHour = new Date(e.starts_at).getHours();
                  return eHour === hour;
                });

                return (
                  <div
                    key={`${dayIdx}-${hour}`}
                    className="relative border-r border-b border-border/50 bg-background hover:bg-muted/50 transition-colors h-12 cursor-pointer group"
                    onClick={() => {
                      const slotStart = new Date(day);
                      slotStart.setHours(hour, 0, 0, 0);
                      onDateSelect(day, slotStart);
                    }}
                  >
                    {/* Add button on hover */}
                    <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                      <Plus className="h-4 w-4 text-muted-foreground" />
                    </div>

                    {/* Events in this slot */}
                    {slotEvents.map((event) => {
                      const layer = primaryLayerFor(event, currentUserId);
                      return (
                        <div
                          key={event.id}
                          className="absolute inset-x-0.5 text-[10px] overflow-hidden"
                          onClick={(e) => {
                            e.stopPropagation();
                            onEventClick(event.id);
                          }}
                        >
                          <EventBlock
                            event={event}
                            layer={layer}
                            variant="time"
                            onClick={() => onEventClick(event.id)}
                          />
                        </div>
                      );
                    })}
                  </div>
                );
              })}
            </React.Fragment>
          ))}
        </div>
      </div>

      {/* Legend */}
      <div className="flex flex-wrap gap-4 text-xs">
        <div className="flex items-center gap-2">
          <div className="h-3 w-3 rounded bg-primary" />
          <span className="text-muted-foreground">My events</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="h-3 w-3 rounded bg-destructive" />
          <span className="text-muted-foreground">Meetings</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="h-3 w-3 rounded bg-warning" />
          <span className="text-muted-foreground">Assessments</span>
        </div>
      </div>
    </div>
  );
}
