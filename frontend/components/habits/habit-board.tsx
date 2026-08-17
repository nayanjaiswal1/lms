"use client";

import { useState } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import Link from "next/link";
import { parseAsArrayOf, parseAsBoolean, parseAsString, parseAsStringLiteral, useQueryState } from "nuqs";
import { toast } from "sonner";
import {
  clearHabitCompletionAction,
  createHabitAction,
  deleteHabitAction,
  setHabitCompletionAction,
  updateHabitAppearanceAction,
  updateHabitColorAction,
  updateHabitCompletionMetadataAction,
} from "@/app/(standalone)/habits/actions";
import { AddHabitInline } from "@/components/habits/add-habit-inline";
import { DailyHabitWheel } from "@/components/habits/daily-habit-wheel";
import { GymPerformanceCard } from "@/components/habits/gym-performance-card";
import { HabitGrid } from "@/components/habits/habit-grid";
import { ReadingProgressCard } from "@/components/habits/reading-progress-card";
import { SleepQualityCard } from "@/components/habits/sleep-quality-chart";
import { Button } from "@/components/ui/button";
import type { HabitColorValue } from "@/lib/constants";
import type { MetadataByKey } from "@/lib/habits/summaries";
import { monthLabel, shiftMonth } from "@/lib/habits/dates";
import type { CustomField, Habit, HabitCadence, HabitCompletion, HabitType } from "@/lib/server/habits";
import { cn } from "@/lib/utils";

export const VIEWS = ["wheel", "grid"] as const;

function completionKey(habitId: string, period: string): string {
  return `${habitId}:${period}`;
}

interface HabitBoardProps {
  month: string;
  initialHabits: Habit[];
  initialCompletions: HabitCompletion[];
}

export function HabitBoard({ month, initialHabits, initialCompletions }: HabitBoardProps) {
  const [view] = useQueryState("view", parseAsStringLiteral(VIEWS).withDefault("wheel"));
  const [selectedTags, setSelectedTags] = useQueryState("tags", parseAsArrayOf(parseAsString).withDefault([]));
  // Wheel is a read-only progress display — no UI toggles this on anymore,
  // ?edit=true still works as a manual override if ever needed.
  const [wheelEditable] = useQueryState("edit", parseAsBoolean.withDefault(false));
  const [habits, setHabits] = useState(initialHabits);
  // Maps "habitId:period" -> check-in count for that period. 1 for a plain
  // daily/monthly/specific-weekday completion; up to a habit's target_count
  // for an "any N times a week" habit.
  const [counts, setCounts] = useState(
    () => new Map(initialCompletions.map((c) => [completionKey(c.habit_id, c.period_start), c.count])),
  );
  const [metadata, setMetadata] = useState<MetadataByKey>(
    () => new Map(initialCompletions.map((c) => [completionKey(c.habit_id, c.period_start), c.metadata ?? {}])),
  );

  async function handleAdd(
    name: string,
    cadence: HabitCadence,
    targetCount?: number,
    weekdays?: number[],
    type?: HabitType,
    customFields?: CustomField[],
  ) {
    const result = await createHabitAction(name, cadence, targetCount, weekdays, type, customFields);
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

  async function handleCustomize(habitId: string, icon: string, tags: string[]): Promise<boolean> {
    const prev = habits.find((h) => h.id === habitId);
    setHabits((p) => p.map((h) => (h.id === habitId ? { ...h, icon, tags } : h)));
    const result = await updateHabitAppearanceAction(habitId, { icon, tags });
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't save that habit's icon and tags.");
      if (prev) setHabits((p) => p.map((h) => (h.id === habitId ? prev : h)));
      return false;
    }
    return true;
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

  // Saving an entry also checks the habit off for that day server-side (see
  // UpsertCompletionMetadata) — mirrored locally so the grid cell updates too.
  async function handleSaveMetadata(habitId: string, period: string, data: Record<string, unknown>): Promise<boolean> {
    const key = completionKey(habitId, period);
    const prevMetadata = metadata.get(key);
    const prevCount = counts.get(key) ?? 0;
    setMetadata((prev) => new Map(prev).set(key, data));
    if (prevCount === 0) setCounts((prev) => new Map(prev).set(key, 1));

    const result = await updateHabitCompletionMetadataAction(habitId, period, data);
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't save that entry.");
      setMetadata((prev) => {
        const next = new Map(prev);
        if (prevMetadata) next.set(key, prevMetadata);
        else next.delete(key);
        return next;
      });
      if (prevCount === 0) {
        setCounts((prev) => {
          const next = new Map(prev);
          next.delete(key);
          return next;
        });
      }
      return false;
    }
    return true;
  }

  const grid = view === "grid";
  // Chips are the union of every habit's own tags — no separate taxonomy to
  // manage, so a tag stops appearing as a filter the moment no habit has it
  // anymore. OR semantics: a habit shows if it carries any selected tag.
  const allTags = Array.from(new Set(habits.flatMap((h) => h.tags))).sort((a, b) => a.localeCompare(b));
  const visibleHabits =
    selectedTags.length === 0 ? habits : habits.filter((h) => h.tags.some((t) => selectedTags.includes(t)));

  function toggleTag(tag: string) {
    setSelectedTags((prev) => (prev.includes(tag) ? prev.filter((t) => t !== tag) : [...prev, tag]));
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

      {(grid || allTags.length > 0) && (
        <div
          className={cn(
            "flex flex-wrap gap-1.5",
            grid ? "items-center" : "flex-col items-end border-l border-border/50 pl-3",
          )}
        >
          {allTags.map((tag) => (
            <Button
              aria-pressed={selectedTags.includes(tag)}
              className={cn("h-7 rounded-full px-3 text-xs", !selectedTags.includes(tag) && "text-muted-foreground")}
              key={tag}
              size="sm"
              type="button"
              variant={selectedTags.includes(tag) ? "secondary" : "outline"}
              onClick={() => toggleTag(tag)}
            >
              {tag}
            </Button>
          ))}
          {selectedTags.length > 0 && (
            <Button
              className="h-7 px-2 text-xs text-muted-foreground"
              size="sm"
              type="button"
              variant="ghost"
              onClick={() => setSelectedTags([])}
            >
              Clear
            </Button>
          )}
          {grid && (
            <div className="ml-auto">
              <AddHabitInline onAdd={handleAdd} />
            </div>
          )}
        </div>
      )}

      {grid ? (
        <>
          <HabitGrid
            counts={counts}
            habits={visibleHabits}
            metadata={metadata}
            month={month}
            onCustomize={handleCustomize}
            onDelete={handleDelete}
            onSaveMetadata={handleSaveMetadata}
            onToggle={handleToggle}
          />
          <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
            <SleepQualityCard habits={visibleHabits} metadata={metadata} month={month} />
            <GymPerformanceCard habits={visibleHabits} metadata={metadata} month={month} />
            <ReadingProgressCard habits={visibleHabits} metadata={metadata} month={month} />
          </div>
        </>
      ) : (
        <DailyHabitWheel
          counts={counts}
          editable={wheelEditable}
          habits={visibleHabits}
          month={month}
          onColorChange={handleColorChange}
          onDelete={handleDelete}
          onToggle={handleToggle}
        />
      )}
    </div>
  );
}
