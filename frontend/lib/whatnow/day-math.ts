// Pure date/pixel math for the Plan Day timeline — native Date only, no date
// library. Mirrors the minimal subset of app/(app)/calendar/calendar-math.ts
// this page needs; duplicated rather than cross-imported since that file is
// route-colocated (not a shared lib) and calendar/whatnow are separate
// eslint-boundaries families.

export const MINUTES_PER_SLOT = 15;
export const PX_PER_HOUR = 56;

export function startOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

export function addDays(date: Date, days: number): Date {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

export function snapMinutes(minutes: number, step = MINUTES_PER_SLOT): number {
  return Math.max(0, Math.round(minutes / step) * step);
}

export function minutesSinceMidnight(date: Date): number {
  return date.getHours() * 60 + date.getMinutes();
}

/** Builds a local Date at dayStart's calendar day, at `minutes` past midnight. */
export function dateAtMinutes(dayStart: Date, minutes: number): Date {
  const d = startOfDay(dayStart);
  d.setMinutes(minutes);
  return d;
}

export function formatTimeLabel(date: Date): string {
  return date.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
}

/** YYYY-MM-DD in local time — the wire format GetDayPlan's ?date= expects. */
export function isoDateParam(date: Date): string {
  const d = startOfDay(date);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}
