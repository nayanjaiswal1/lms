"use client";

import dynamic from "next/dynamic";
import { Moon } from "lucide-react";
import { Skeleton } from "@/components/ui/skeleton";
import { latestMetadataEntry, latestSleepTimes, sleepSeriesForMonth, type MetadataByKey } from "@/lib/habits/summaries";
import type { Habit } from "@/lib/server/habits";

const SleepQualityChartInner = dynamic(() => import("@/components/habits/sleep-quality-chart-inner"), {
  ssr: false,
  loading: () => <Skeleton className="h-[220px] w-full" />,
});

interface SleepQualityCardProps {
  habits: Habit[];
  month: string;
  metadata: MetadataByKey;
}

// Real data only — driven by the user's "sleep"-type habit's stored
// slept_at/woke_up entries (see habit-entry-form.tsx), never sample numbers.
export function SleepQualityCard({ habits, month, metadata }: SleepQualityCardProps) {
  const habit = habits.find((h) => h.type === "sleep");
  if (!habit) {
    return (
      <section className="rounded-lg border border-border p-6">
        <h2 className="habits-journal-headline mb-4 border-b border-border pb-2 text-xs font-semibold uppercase tracking-widest text-muted-foreground">
          Sleep Quality
        </h2>
        <div className="empty-state py-8">
          <p className="text-sm text-muted-foreground">Add a Sleep habit to see this chart.</p>
        </div>
      </section>
    );
  }

  const points = sleepSeriesForMonth(habit, month, metadata);
  const times = latestSleepTimes(habit, month, metadata);
  const hasData = points.some((p) => p.hours !== null);
  const latestEntry = latestMetadataEntry(habit, month, metadata);
  const wakes = typeof latestEntry?.night_wakes === "number" ? latestEntry.night_wakes : null;

  return (
    <section className="rounded-lg border border-border p-6">
      <h2 className="habits-journal-headline mb-4 border-b border-border pb-2 text-xs font-semibold uppercase tracking-widest text-muted-foreground">
        Sleep Quality
      </h2>
      {hasData ? (
        <>
          <SleepQualityChartInner points={points} />
          {times && (
            <div className="mt-4 flex items-center justify-between border-t border-border px-2 pt-4">
              <div className="flex flex-col">
                <span className="text-[10px] uppercase tracking-widest text-primary">Sleep Start</span>
                <span className="text-sm">{times.sleptAt}</span>
              </div>
              <div className="flex flex-col text-right">
                <span className="text-[10px] uppercase tracking-widest text-primary">Wake Up</span>
                <span className="text-sm">{times.wokeUp}</span>
              </div>
            </div>
          )}
          {wakes !== null && (
            <div className="mt-3 inline-flex items-center gap-1.5 rounded-sm border border-border bg-muted/30 px-2 py-1 text-xs text-muted-foreground">
              <Moon aria-hidden className="size-3" />
              {wakes} {wakes === 1 ? "wake" : "wakes"} last night
            </div>
          )}
        </>
      ) : (
        <div className="empty-state py-8">
          <p className="text-sm text-muted-foreground">Click {habit.name} on the grid to log tonight's sleep.</p>
        </div>
      )}
    </section>
  );
}
