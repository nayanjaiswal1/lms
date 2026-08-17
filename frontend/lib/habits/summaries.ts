import { dateAt, daysInMonth, elapsedDays } from "@/lib/habits/dates";
import type { Habit } from "@/lib/server/habits";

// Shared by sleep-quality-chart / gym-performance-card — both derive their
// numbers from real completions.metadata (see lib/habits/type-schemas.ts for
// the field keys), never hardcoded sample data.

export type MetadataByKey = Map<string, Record<string, unknown>>;

function metadataFor(habitId: string, period: string, metadata: MetadataByKey): Record<string, unknown> {
  return metadata.get(`${habitId}:${period}`) ?? {};
}

// "HH:MM" -> minutes since midnight, or null if unset/malformed.
function parseTimeOfDay(value: unknown): number | null {
  if (typeof value !== "string") return null;
  const m = /^(\d{1,2}):(\d{2})$/.exec(value);
  if (!m) return null;
  return Number(m[1]) * 60 + Number(m[2]);
}

// Duration from sleptAt to wokeUp, wrapping past midnight — a 22:30 -> 06:00
// entry is 7.5h, not a negative span.
function sleepHours(sleptAt: unknown, wokeUp: unknown): number | null {
  const start = parseTimeOfDay(sleptAt);
  const end = parseTimeOfDay(wokeUp);
  if (start === null || end === null) return null;
  return ((end - start + 1440) % 1440) / 60;
}

export interface SleepPoint {
  day: number;
  hours: number | null;
  wakes: number | null;
}

// "1"/"2" etc coerced from the number field; blank/non-numeric -> null so the
// bar layer skips the day instead of drawing a false zero.
function parseWakes(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

// One point per elapsed day of the month — future days are omitted rather
// than plotted as zero, so the line only ever draws through days that could
// actually have data.
export function sleepSeriesForMonth(habit: Habit, month: string, metadata: MetadataByKey): SleepPoint[] {
  const days = elapsedDays(month, daysInMonth(month));
  const points: SleepPoint[] = [];
  for (let day = 1; day <= days; day++) {
    const entry = metadataFor(habit.id, dateAt(month, day), metadata);
    points.push({ day, hours: sleepHours(entry.slept_at, entry.woke_up), wakes: parseWakes(entry.night_wakes) });
  }
  return points;
}

export interface SleepTimes {
  sleptAt: string;
  wokeUp: string;
}

// Most recent elapsed day with both times recorded — the footer stat under
// the chart, matching the mockup's "Sleep Start / Wake Up" row.
export function latestSleepTimes(habit: Habit, month: string, metadata: MetadataByKey): SleepTimes | null {
  const days = elapsedDays(month, daysInMonth(month));
  for (let day = days; day >= 1; day--) {
    const entry = metadataFor(habit.id, dateAt(month, day), metadata);
    if (typeof entry.slept_at === "string" && typeof entry.woke_up === "string") {
      return { sleptAt: entry.slept_at, wokeUp: entry.woke_up };
    }
  }
  return null;
}

// Most recent elapsed day with any metadata recorded — type-agnostic, shared
// by GymPerformanceCard and ReadingProgressCard.
export function latestMetadataEntry(habit: Habit, month: string, metadata: MetadataByKey): Record<string, unknown> | null {
  const days = elapsedDays(month, daysInMonth(month));
  for (let day = days; day >= 1; day--) {
    const entry = metadataFor(habit.id, dateAt(month, day), metadata);
    if (Object.keys(entry).length > 0) return entry;
  }
  return null;
}

// Sum of a numeric field across every elapsed day of the month — e.g. total
// pages read, for the "logged data adds up to something" view rather than
// just the latest entry.
export function sumNumericField(habit: Habit, month: string, metadata: MetadataByKey, field: string): number {
  const days = elapsedDays(month, daysInMonth(month));
  let total = 0;
  for (let day = 1; day <= days; day++) {
    const entry = metadataFor(habit.id, dateAt(month, day), metadata);
    if (typeof entry[field] === "number" && Number.isFinite(entry[field])) total += entry[field] as number;
  }
  return total;
}
