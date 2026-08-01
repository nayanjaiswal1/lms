"use client";

import * as React from "react";
import { toast } from "sonner";

import { cn } from "@/lib/utils";
import { getMentorSlotsAction, type Slot } from "@/lib/server/sessions";
import { SlotGrid } from "./slot-grid";

const DAYS_AHEAD = 14;

interface DayOption {
  key: string;
  weekday: string;
  dayLabel: string;
}

/** Local-calendar-day key (yyyy-mm-dd) — avoids the UTC date shift that
 * `toISOString().slice(0, 10)` would introduce for timezones behind UTC. */
function dateKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function buildDayOptions(): DayOption[] {
  const today = new Date();
  return Array.from({ length: DAYS_AHEAD }, (_, i) => {
    const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() + i);
    return {
      key: dateKey(d),
      weekday: d.toLocaleDateString(undefined, { weekday: "short" }),
      dayLabel: d.toLocaleDateString(undefined, { day: "numeric", month: "short" }),
    };
  });
}

function dayBounds(key: string): { from: string; to: string } {
  const [y, m, d] = key.split("-").map(Number);
  return {
    from: new Date(y, m - 1, d, 0, 0, 0, 0).toISOString(),
    to: new Date(y, m - 1, d, 23, 59, 59, 999).toISOString(),
  };
}

interface DayView {
  day: string;
  slots: Slot[];
  loading: boolean;
  selected: string | null;
}

interface SlotPickerProps {
  /** Whose availability to show. Changing it reloads the current day. */
  mentorId: string;
  /** Fires with the chosen slot, or null when the selection is cleared. */
  onSelect: (slot: Slot | null) => void;
}

/**
 * The day strip + open-slot grid, shared by the booking and reschedule
 * dialogs. Owns which day is showing and which slot is picked; the parent
 * only needs the resulting slot.
 */
export function SlotPicker({ mentorId, onSelect }: SlotPickerProps) {
  const days = React.useMemo(buildDayOptions, []);

  // One state object: picking a day clears the old slots and the selection,
  // so they always move together.
  const [view, setView] = React.useState<DayView>({
    day: days[0].key,
    slots: [],
    loading: false,
    selected: null,
  });

  // Tracks the day/mentor pair the latest request was for, so a slow response
  // for a day the user has already navigated away from is discarded instead of
  // overwriting the newer results.
  const latest = React.useRef("");

  // Touches only this component's own state, never the parent's — so the
  // first-render kickoff below can't update another component mid-render.
  const loadDay = React.useCallback(
    async (day: string) => {
      if (!mentorId) return;
      const token = `${mentorId}|${day}`;
      latest.current = token;
      setView((v) => ({ ...v, day, loading: true, selected: null }));

      const { from, to } = dayBounds(day);
      const result = await getMentorSlotsAction(mentorId, from, to);
      // A slow response for a day the user has already navigated away from
      // must not overwrite the newer results.
      if (latest.current !== token) return;

      if (!result.ok || !result.data) {
        toast.error(result.error ?? "Couldn't load times for that day.");
        setView((v) => ({ ...v, loading: false, slots: [] }));
        return;
      }
      const { slots } = result.data;
      setView((v) => ({ ...v, loading: false, slots }));
    },
    [mentorId],
  );

  // ponytail: fetch kicked off from the first render rather than useEffect,
  // which the frontend rules ban. The picker only ever mounts inside an open
  // dialog, so "on mount" is the correct trigger, and the ref guard keeps it
  // to once per mentor.
  const loadedFor = React.useRef<string | null>(null);
  if (loadedFor.current !== mentorId) {
    loadedFor.current = mentorId;
    void loadDay(view.day);
  }

  return (
    <>
      <div aria-label="Choose a day" className="flex gap-2 overflow-x-auto pb-2" role="tablist">
        {days.map((d) => (
          <button
            aria-selected={view.day === d.key}
            className={cn(
              "flex min-w-16 shrink-0 flex-col items-center gap-0.5 rounded-md border border-border px-3 py-2 text-sm transition-colors duration-fast touch-target",
              view.day === d.key
                ? "border-primary bg-primary text-primary-foreground"
                : "bg-background hover:bg-accent hover:text-accent-foreground",
            )}
            key={d.key}
            role="tab"
            type="button"
            onClick={() => {
              onSelect(null);
              void loadDay(d.key);
            }}
          >
            <span className="text-xs uppercase tracking-wide opacity-80">{d.weekday}</span>
            <span className="font-semibold">{d.dayLabel}</span>
          </button>
        ))}
      </div>

      <SlotGrid
        loading={view.loading}
        selected={view.selected}
        slots={view.slots}
        onSelect={(startsAt) => {
          setView((v) => ({ ...v, selected: startsAt }));
          onSelect(view.slots.find((s) => s.starts_at === startsAt) ?? null);
        }}
      />
    </>
  );
}
