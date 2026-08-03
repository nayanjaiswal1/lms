"use client";

import { useState } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import Link from "next/link";
import { toast } from "sonner";
import {
  clearHabitCompletionAction,
  createHabitAction,
  deleteHabitAction,
  setHabitCompletionAction,
  updateHabitColorAction,
} from "@/app/(app)/habits/actions";
import { AddHabitInline } from "@/components/habits/add-habit-inline";
import { DailyHabitWheel } from "@/components/habits/daily-habit-wheel";
import { Button } from "@/components/ui/button";
import type { HabitColorValue } from "@/lib/constants";
import { monthLabel, shiftMonth } from "@/lib/habits/dates";
import type { Habit, HabitCadence, HabitCompletion } from "@/lib/server/habits";

function completionKey(habitId: string, period: string): string {
  return `${habitId}:${period}`;
}

interface HabitBoardProps {
  month: string;
  initialHabits: Habit[];
  initialCompletions: HabitCompletion[];
}

export function HabitBoard({ month, initialHabits, initialCompletions }: HabitBoardProps) {
  const [habits, setHabits] = useState(initialHabits);
  // Maps "habitId:period" -> check-in count for that period. 1 for a plain
  // daily/monthly/specific-weekday completion; up to a habit's target_count
  // for an "any N times a week" habit.
  const [counts, setCounts] = useState(
    () => new Map(initialCompletions.map((c) => [completionKey(c.habit_id, c.period_start), c.count])),
  );

  async function handleAdd(name: string, cadence: HabitCadence, targetCount?: number, weekdays?: number[]) {
    const result = await createHabitAction(name, cadence, targetCount, weekdays);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Couldn't add habit.");
      return;
    }
    setHabits((prev) => [...prev, result.data as Habit]);
  }

  async function handleDelete(habitId: string) {
    setHabits((prev) => prev.filter((h) => h.id !== habitId));
    const result = await deleteHabitAction(habitId);
    if (!result.ok) toast.error(result.error ?? "Couldn't delete habit.");
  }

  async function handleColorChange(habitId: string, color: HabitColorValue) {
    const prevColor = habits.find((h) => h.id === habitId)?.color;
    setHabits((prev) => prev.map((h) => (h.id === habitId ? { ...h, color } : h)));
    const result = await updateHabitColorAction(habitId, color);
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't change that habit's color.");
      if (prevColor) setHabits((prev) => prev.map((h) => (h.id === habitId ? { ...h, color: prevColor } : h)));
    }
  }

  // done=true means the period already met its target — the next click
  // resets it to 0. done=false means one more check-in is owed — the next
  // click adds one, which the caller already confirmed stays under target.
  async function handleToggle(habitId: string, period: string, done: boolean) {
    const key = completionKey(habitId, period);
    const prevCount = counts.get(key) ?? 0;
    const nextCount = done ? 0 : prevCount + 1;
    setCounts((prev) => {
      const next = new Map(prev);
      if (nextCount === 0) next.delete(key);
      else next.set(key, nextCount);
      return next;
    });
    const result = done
      ? await clearHabitCompletionAction(habitId, period)
      : await setHabitCompletionAction(habitId, period);
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't save that check-off.");
      setCounts((prev) => {
        const next = new Map(prev);
        if (prevCount === 0) next.delete(key);
        else next.set(key, prevCount);
        return next;
      });
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-center gap-4">
        <Button asChild aria-label="Previous month" className="touch-target" size="icon" variant="ghost">
          <Link href={`/habits?month=${shiftMonth(month, -1)}`}>
            <ChevronLeft aria-hidden className="size-4" />
          </Link>
        </Button>
        <span className="min-w-40 text-center font-semibold">{monthLabel(month)}</span>
        <Button asChild aria-label="Next month" className="touch-target" size="icon" variant="ghost">
          <Link href={`/habits?month=${shiftMonth(month, 1)}`}>
            <ChevronRight aria-hidden className="size-4" />
          </Link>
        </Button>
      </div>

      <div className="max-w-xl">
        <AddHabitInline onAdd={handleAdd} />
      </div>

      <DailyHabitWheel
        counts={counts}
        habits={habits}
        month={month}
        onColorChange={handleColorChange}
        onDelete={handleDelete}
        onToggle={handleToggle}
      />
    </div>
  );
}
