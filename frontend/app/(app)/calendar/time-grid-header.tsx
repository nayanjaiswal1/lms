"use client";

import { dateAtMinutes, isSameDay, startOfDay } from "@/app/(app)/calendar/calendar-math";
import { EnhancedQuickCreate } from "@/app/(app)/calendar/enhanced-quick-create";
import { Popover, PopoverAnchor, PopoverContent } from "@/components/ui/popover";
import type { CalendarEventPriority } from "@/lib/calendar/types";
import { cn } from "@/lib/utils";

interface TimeGridHeaderProps {
  days: Date[];
  columns: string;
  now: Date | null;
  creatingSlot: { day: Date; minutes: number } | null;
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

export function TimeGridHeader({ days, columns, now, creatingSlot, onCreateSubmit, onCreateCancel }: TimeGridHeaderProps) {
  return (
    // eslint-disable-next-line no-restricted-syntax -- column count varies with view (1 day vs 7-day week), not expressible as a static token
    <div className="grid border-b border-border bg-muted/40" style={{ gridTemplateColumns: columns }}>
      <div className="border-r border-border" />
      {days.map((day) => {
        // Anchored here (the day header) rather than at the clicked slot inside
        // the scrollable grid below — that scrolls independently of the page, so
        // a popover anchored to a point inside it would scroll out of view (and
        // Radix would float it to wherever that now off-screen point maps to)
        // every time the user scrolled the day/week grid while creating.
        const isCreatingHere = Boolean(creatingSlot && isSameDay(creatingSlot.day, day));
        const isToday = Boolean(now && isSameDay(day, now));
        return (
          <Popover key={day.toISOString()} open={isCreatingHere} onOpenChange={(open) => !open && onCreateCancel()}>
            <PopoverAnchor asChild>
              <div
                aria-current={isToday ? "date" : undefined}
                className="flex min-w-0 flex-col items-center gap-0.5 border-r border-border px-0.5 py-2 last:border-r-0"
              >
                <span className={cn("text-xs font-medium uppercase", isToday ? "text-primary" : "text-muted-foreground")}>
                  {day.toLocaleDateString(undefined, { weekday: "short" })}
                </span>
                <span
                  className={cn(
                    "flex h-8 w-8 items-center justify-center rounded-full text-sm font-semibold tabular-nums",
                    isToday && "bg-primary text-primary-foreground",
                  )}
                >
                  {day.getDate()}
                </span>
              </div>
            </PopoverAnchor>
            {isCreatingHere && creatingSlot && (
              <PopoverContent
                align="center"
                className="w-80 max-w-[calc(100vw-2rem)]"
                collisionPadding={16}
                side="bottom"
                onClick={(e) => e.stopPropagation()}
              >
                <EnhancedQuickCreate
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
  );
}
