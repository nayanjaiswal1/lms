// ─────────────────────────────────────────────
// Pure date math for the calendar grid — native Date only, no date library.
// All functions operate in the browser's local time zone; events arrive from
// the API as UTC ISO strings and `new Date(iso)` + local getters/setters
// already convert correctly, so no manual timezone conversion is needed.
// ─────────────────────────────────────────────

import type { CalendarView } from "@/lib/calendar/types";

export const MINUTES_PER_SLOT = 15;
export const PX_PER_HOUR = 56;

export function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

export function startOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

export function endOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(23, 59, 59, 999);
  return d;
}

export function addDays(date: Date, days: number): Date {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

export function addMonths(date: Date, months: number): Date {
  const d = new Date(date);
  d.setMonth(d.getMonth() + months);
  return d;
}

// Weeks start on Sunday.
export function startOfWeek(date: Date): Date {
  return addDays(startOfDay(date), -date.getDay());
}

export function startOfMonth(date: Date): Date {
  const d = new Date(date.getFullYear(), date.getMonth(), 1);
  return startOfDay(d);
}

export function endOfMonth(date: Date): Date {
  const d = new Date(date.getFullYear(), date.getMonth() + 1, 0);
  return endOfDay(d);
}

/** 42-day (6-week) grid for the month view, including the leading/trailing
 * days borrowed from adjacent months so every week row is complete. */
export function getMonthGridDays(anchor: Date): Date[] {
  const gridStart = startOfWeek(startOfMonth(anchor));
  return Array.from({ length: 42 }, (_, i) => addDays(gridStart, i));
}

export function getWeekDays(anchor: Date): Date[] {
  const weekStart = startOfWeek(anchor);
  return Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));
}

/** The [from, to) UTC range to request from the API for a given view. Month
 * requests the full 6-week grid so borrowed adjacent-month days render too;
 * agenda requests a rolling 30-day window. */
export function rangeForView(view: CalendarView, anchor: Date): { from: Date; to: Date } {
  switch (view) {
    case "day":
      return { from: startOfDay(anchor), to: endOfDay(anchor) };
    case "week": {
      const days = getWeekDays(anchor);
      return { from: startOfDay(days[0]), to: endOfDay(days[6]) };
    }
    case "agenda":
      return { from: startOfDay(anchor), to: endOfDay(addDays(anchor, 30)) };
    case "month":
    default: {
      const days = getMonthGridDays(anchor);
      return { from: startOfDay(days[0]), to: endOfDay(days[41]) };
    }
  }
}

export function formatRangeLabel(view: CalendarView, anchor: Date): string {
  switch (view) {
    case "day":
      return anchor.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric", year: "numeric" });
    case "week": {
      const days = getWeekDays(anchor);
      const start = days[0];
      const end = days[6];
      const sameMonth = start.getMonth() === end.getMonth();
      const startLabel = start.toLocaleDateString(undefined, { month: "short", day: "numeric" });
      // {day, year} with no month is an ambiguous combination — Chrome's Intl
      // formatter falls back to a verbose "(day: 11)" rendering for it — so
      // the same-month case is built from primitives instead of Intl.
      const endLabel = sameMonth
        ? `${end.getDate()}, ${end.getFullYear()}`
        : end.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
      return `${startLabel} – ${endLabel}`;
    }
    case "agenda":
      return `Next 30 days from ${anchor.toLocaleDateString(undefined, { month: "short", day: "numeric" })}`;
    case "month":
    default:
      return anchor.toLocaleDateString(undefined, { month: "long", year: "numeric" });
  }
}

export function stepAnchor(view: CalendarView, anchor: Date, direction: 1 | -1): Date {
  switch (view) {
    case "day":
      return addDays(anchor, direction);
    case "week":
      return addDays(anchor, direction * 7);
    case "agenda":
      return addDays(anchor, direction * 30);
    case "month":
    default:
      return addMonths(anchor, direction);
  }
}

export function snapMinutes(minutes: number, step = MINUTES_PER_SLOT): number {
  return Math.max(0, Math.round(minutes / step) * step);
}

export function minutesSinceMidnight(date: Date): number {
  return date.getHours() * 60 + date.getMinutes();
}

/** Builds a local Date at `dayStart`'s calendar day, at `minutes` past midnight. */
export function dateAtMinutes(dayStart: Date, minutes: number): Date {
  const d = startOfDay(dayStart);
  d.setMinutes(minutes);
  return d;
}

export function formatTimeLabel(date: Date): string {
  return date.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
}

export function isoDateParam(date: Date): string {
  return date.toISOString();
}
