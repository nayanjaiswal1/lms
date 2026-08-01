"use client";

import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import type { Slot } from "@/lib/server/sessions";

interface SlotGridProps {
  slots: Slot[];
  selected: string | null;
  loading: boolean;
  onSelect: (startsAt: string) => void;
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
}

/**
 * Presentational grid of time-slot buttons for one day. Split out of
 * BookSessionDialog to keep that file under the 300-line component cap.
 *
 * Taken slots are rendered disabled, not hidden — the mentor's day should
 * read as a real schedule with real gaps, not a suspiciously sparse list.
 */
export function SlotGrid({ slots, selected, loading, onSelect }: SlotGridProps) {
  if (loading) {
    return (
      <div aria-busy="true" aria-label="Loading available times" className="grid-responsive-4">
        {Array.from({ length: 8 }).map((_, i) => (
          <Skeleton className="h-10" key={i} />
        ))}
      </div>
    );
  }

  if (slots.length === 0) {
    return (
      <div className="empty-state py-8">
        <p className="text-sm">This mentor has no availability on this day.</p>
      </div>
    );
  }

  return (
    <div aria-label="Available times" className="grid-responsive-4" role="group">
      {slots.map((slot) => {
        const time = formatTime(slot.starts_at);
        const isSelected = selected === slot.starts_at;
        return (
          <Button
            aria-label={slot.taken ? `${time} — already booked` : `${time} — available`}
            aria-pressed={isSelected}
            className={cn("touch-target", slot.taken && "opacity-50 line-through")}
            disabled={slot.taken}
            key={slot.starts_at}
            size="sm"
            type="button"
            variant={isSelected ? "default" : slot.taken ? "secondary" : "outline"}
            onClick={() => onSelect(slot.starts_at)}
          >
            {time}
          </Button>
        );
      })}
    </div>
  );
}
