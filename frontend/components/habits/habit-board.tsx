"use client";

import { useState } from "react";
import { ChevronLeft, ChevronRight, LayoutGrid, Pencil, PieChart } from "lucide-react";
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
} from "@/app/(app)/habits/actions";
import { AddHabitInline } from "@/components/habits/add-habit-inline";
import { DailyHabitWheel } from "@/components/habits/daily-habit-wheel";
import { GymPerformanceCard } from "@/components/habits/gym-performance-card";
import { HabitGrid } from "@/components/habits/habit-grid";
import { journalSans, journalSerif } from "@/components/habits/journal-fonts";
import "@/components/habits/journal-theme.css";
import { SleepQualityCard } from "@/components/habits/sleep-quality-chart";
import { Button } from "@/components/ui/button";
import type { HabitColorValue } from "@/lib/constants";
import type { MetadataByKey } from "@/lib/habits/summaries";
import { monthLabel, shiftMonth } from "@/lib/habits/dates";
import type { CustomField, Habit, HabitCadence, HabitCompletion, HabitType } from "@/lib/server/habits";
import { cn } from "@/lib/utils";

const VIEWS = ["wheel", "grid"] as const;

function completionKey(habitId: string, period: string): string {
  return `${habitId}:${period}`;
}

interface HabitBoardProps {
  month: string;
  initialHabits: Habit[];
  initialCompletions: HabitCompletion[];
}

export function HabitBoard({ month, initialHabits, initialCompletions }: HabitBoardProps) {
  const [view, setView] = useQueryState("view", parseAsStringLiteral(VIEWS).withDefault("wheel"));
  const [selectedTags, setSelectedTags] = useQueryState("tags", parseAsArrayOf(parseAsString).withDefault([]));
  // Wheel starts read-only — it's a progress display first, editable only once toggled on.
  const [wheelEditable, setWheelEditable] = useQueryState("edit", parseAsBoolean.withDefault(false));
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
    <div
      className={cn("flex flex-col gap-6 habits-journal", journalSans.variable, journalSerif.variable)}
    >
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

      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="max-w-xl flex-1">
          <AddHabitInline onAdd={handleAdd} />
        </div>
        <div className="flex items-center gap-2">
          {!grid && (
            <Button
              aria-pressed={wheelEditable}
              className={cn("touch-target", !wheelEditable && "text-muted-foreground")}
              size="sm"
              // Amber/primary while active — matches the design system's
              // "amber = human action" convention instead of the neutral
              // secondary tint, so the editing state reads as a deliberate
              // mode change rather than just a selected pill.
              variant={wheelEditable ? "default" : "outline"}
              onClick={() => setWheelEditable((prev) => !prev)}
            >
              <Pencil aria-hidden className="h-4 w-4" />
              {wheelEditable ? "Editing" : "Edit"}
            </Button>
          )}
          <div className="flex w-fit gap-1 rounded-md border border-border p-1">
            <Button
              aria-label="Wheel view"
              className={cn("touch-target", view !== "wheel" && "text-muted-foreground")}
              size="sm"
              variant={view === "wheel" ? "secondary" : "ghost"}
              onClick={() => setView("wheel")}
            >
              <PieChart aria-hidden className="h-4 w-4" />
              Wheel
            </Button>
            <Button
              aria-label="Grid view"
              className={cn("touch-target", view !== "grid" && "text-muted-foreground")}
              size="sm"
              variant={view === "grid" ? "secondary" : "ghost"}
              onClick={() => setView("grid")}
            >
              <LayoutGrid aria-hidden className="h-4 w-4" />
              Grid
            </Button>
          </div>
        </div>
      </div>

      {allTags.length > 0 && (
        <div className="flex flex-wrap items-center gap-1.5">
          {allTags.map((tag) => (
            <Button
              aria-pressed={selectedTags.includes(tag)}
              className={cn("touch-target h-7 rounded-full px-3 text-xs", !selectedTags.includes(tag) && "text-muted-foreground")}
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
              className="touch-target h-7 px-2 text-xs text-muted-foreground"
              size="sm"
              type="button"
              variant="ghost"
              onClick={() => setSelectedTags([])}
            >
              Clear
            </Button>
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
