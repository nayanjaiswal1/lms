"use client";

import { useState } from "react";
import { CADENCE_ORDER } from "@/components/habits/daily-habit-wheel";
import { HabitEntryForm } from "@/components/habits/habit-entry-form";
import { HabitGridRow } from "@/components/habits/habit-grid-row";
import { dateAt, daysInMonth, elapsedDays, todayInMonth } from "@/lib/habits/dates";
import { hasEntryForm } from "@/lib/habits/type-schemas";
import type { MetadataByKey } from "@/lib/habits/summaries";
import type { Habit } from "@/lib/server/habits";
import { cn } from "@/lib/utils";

interface HabitGridProps {
  habits: Habit[];
  month: string;
  counts: Map<string, number>;
  metadata: MetadataByKey;
  onDelete: (habitId: string) => void;
  onToggle: (habitId: string, period: string, done: boolean) => void;
  onSaveMetadata: (habitId: string, period: string, data: Record<string, unknown>) => Promise<boolean>;
  onCustomize: (habitId: string, icon: string, tags: string[]) => Promise<boolean>;
}

// "1% Better" journal grid — table alternative to the daily habit wheel, same
// data and cadence math (cellsForHabit via HabitGridRow), laid out as a
// 30-day table. Clicking a typed habit's name opens its entry form below the
// table for today (see docs/plan: entries are today-only for now).
export function HabitGrid({ habits, month, counts, metadata, onDelete, onToggle, onSaveMetadata, onCustomize }: HabitGridProps) {
  const [selectedHabitId, setSelectedHabitId] = useState<string | null>(null);
  const days = daysInMonth(month);
  const today = todayInMonth(month);
  const elapsed = elapsedDays(month, days);
  const todayPeriod = today !== null ? dateAt(month, today) : null;
  const orderedHabits = [...habits].sort((a, b) => CADENCE_ORDER[a.cadence] - CADENCE_ORDER[b.cadence]);
  const selectedHabit = orderedHabits.find((h) => h.id === selectedHabitId);

  return (
    <section>
      {orderedHabits.length === 0 ? (
        <p className="text-sm text-muted-foreground">Add a habit to start.</p>
      ) : (
        <div className="table-responsive">
          <table className="w-full min-w-max border-collapse text-sm">
            <thead>
              <tr className="whitespace-nowrap">
                <th className="sticky left-0 z-raised border-r border-b border-border bg-card p-2 text-left font-medium">
                  Habit
                </th>
                {Array.from({ length: days }, (_, i) => {
                  const day = i + 1;
                  const isToday = day === today;
                  return (
                    <th
                      className={cn(
                        "relative w-9 border-b p-1 text-center text-xs font-normal",
                        isToday ? "border-b-2 border-primary font-semibold text-primary" : "border-border text-muted-foreground",
                      )}
                      key={`day-${day}`}
                    >
                      {isToday && (
                        <span className="absolute -top-3 left-1/2 -translate-x-1/2 text-[9px] font-bold tracking-wide">TODAY</span>
                      )}
                      {day}
                    </th>
                  );
                })}
                <th className="border-b border-border p-2 text-center text-xs font-medium text-muted-foreground">Completion</th>
                <th className="border-b border-border p-2 text-center text-xs font-medium text-muted-foreground">Streak</th>
                <th className="border-b border-border p-2 text-center text-xs font-medium text-muted-foreground">Actions</th>
              </tr>
            </thead>
            <tbody>
              {orderedHabits.map((habit) => (
                <HabitGridRow
                  counts={counts}
                  days={days}
                  elapsed={elapsed}
                  habit={habit}
                  key={habit.id}
                  month={month}
                  selected={habit.id === selectedHabitId}
                  onCustomize={onCustomize}
                  onDelete={onDelete}
                  onSelect={() => setSelectedHabitId((prev) => (prev === habit.id ? null : habit.id))}
                  onToggle={onToggle}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}

      {selectedHabit && hasEntryForm(selectedHabit) && todayPeriod && (
        <div className="mt-4">
          <HabitEntryForm
            habit={selectedHabit}
            initialMetadata={metadata.get(`${selectedHabit.id}:${todayPeriod}`) ?? {}}
            period={todayPeriod}
            onClose={() => setSelectedHabitId(null)}
            onSave={(data) => onSaveMetadata(selectedHabit.id, todayPeriod, data)}
          />
        </div>
      )}
    </section>
  );
}
