"use client";

import { useState } from "react";
import { Check, MoreHorizontal, X } from "lucide-react";
import { CADENCE_ICON, cellsForHabit, type WheelCell } from "@/components/habits/daily-habit-wheel";
import { HabitCustomizeDialog } from "@/components/habits/habit-customize-dialog";
import { HabitIcon } from "@/components/habits/habit-icon";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { HABIT_TYPE_ICON, hasEntryForm } from "@/lib/habits/type-schemas";
import type { Habit } from "@/lib/server/habits";
import { cn } from "@/lib/utils";

// Consecutive completed periods counting back from the most recent one that
// has actually happened (see elapsedDays) — a habit's remaining, not-yet-lived
// periods this month don't count as a break.
function currentStreak(cells: WheelCell[], counts: Map<string, number>, habitId: string, target: number, elapsed: number): number {
  const happened = cells.filter((cell) => cell.interactive && cell.endDay <= elapsed);
  let streak = 0;
  for (let i = happened.length - 1; i >= 0; i--) {
    const count = counts.get(`${habitId}:${happened[i].period}`) ?? 0;
    if (count < target) break;
    streak++;
  }
  return streak;
}

interface HabitGridRowProps {
  habit: Habit;
  month: string;
  days: number;
  elapsed: number;
  counts: Map<string, number>;
  selected: boolean;
  onSelect: () => void;
  onDelete: (habitId: string) => void;
  onToggle: (habitId: string, period: string, done: boolean) => void;
  onCustomize: (habitId: string, icon: string, tags: string[]) => Promise<boolean>;
}

// One row of the journal-themed grid — done/missed/future marks (check / x /
// dot) are derived purely from the existing count+elapsed data, no new
// stored state. A row whose habit has an entry form (see type-schemas.ts)
// has a clickable name that opens it below the grid instead of just showing
// the cadence icon.
export function HabitGridRow({ habit, month, days, elapsed, counts, selected, onSelect, onDelete, onToggle, onCustomize }: HabitGridRowProps) {
  const [customizeOpen, setCustomizeOpen] = useState(false);
  const rowFallbackIcon = hasEntryForm(habit) ? HABIT_TYPE_ICON[habit.type] : CADENCE_ICON[habit.cadence];
  const target = habit.cadence === "weekly" && habit.weekdays.length === 0 ? habit.target_count : 1;
  const cells = cellsForHabit(habit, month, days);
  const interactiveCells = cells.filter((cell) => cell.interactive);
  const doneCount = interactiveCells.filter((cell) => (counts.get(`${habit.id}:${cell.period}`) ?? 0) >= target).length;
  const streak = currentStreak(cells, counts, habit.id, target, elapsed);
  const clickable = hasEntryForm(habit);

  return (
    <tr className={cn("group whitespace-nowrap", selected && "bg-accent/40")}>
      <th className="sticky left-0 z-raised border-r border-border bg-card p-2 text-left font-normal">
        <div className="flex items-center gap-1.5">
          {clickable ? (
            <button
              aria-expanded={selected}
              className="flex min-w-0 flex-1 items-center gap-1.5 text-left hover:text-primary"
              type="button"
              onClick={onSelect}
            >
              <HabitIcon className="size-3 shrink-0 text-muted-foreground" fallback={rowFallbackIcon} icon={habit.icon} />
              <span className="min-w-0 flex-1 truncate pr-1">{habit.name}</span>
            </button>
          ) : (
            <>
              <HabitIcon className="size-3 shrink-0 text-muted-foreground" fallback={rowFallbackIcon} icon={habit.icon} />
              <span className="min-w-0 flex-1 truncate pr-1">{habit.name}</span>
            </>
          )}
        </div>
      </th>
      {cells.map((cell) => {
        const count = counts.get(`${habit.id}:${cell.period}`) ?? 0;
        const done = count >= target;
        const missed = cell.interactive && !done && cell.endDay <= elapsed && target === 1;
        return (
          <td className="h-9 border-l border-border p-0 text-center" colSpan={cell.endDay - cell.startDay + 1} key={cell.period}>
            {cell.interactive ? (
              <button
                aria-label={
                  target > 1
                    ? `${habit.name}, ${cell.label}, ${count} of ${target}`
                    : `${habit.name}, ${cell.label}, ${done ? "done" : missed ? "missed" : "not yet"}`
                }
                className="flex h-full min-h-9 w-full items-center justify-center text-xs text-foreground/70 transition-colors duration-fast hover:bg-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-ring"
                type="button"
                onClick={() => onToggle(habit.id, cell.period, done)}
              >
                {target > 1 ? (
                  `${count}/${target}`
                ) : done ? (
                  <Check aria-hidden className="size-3.5 text-foreground" strokeWidth={2.5} />
                ) : missed ? (
                  <X aria-hidden className="size-3 text-muted-foreground" />
                ) : (
                  <span aria-hidden className="block size-1.5 rounded-full bg-border" />
                )}
              </button>
            ) : (
              <div aria-hidden className="h-full min-h-9 w-full bg-muted/20" />
            )}
          </td>
        );
      })}
      <td className="border-l border-border p-2 text-center text-muted-foreground">
        {doneCount}/{interactiveCells.length}
      </td>
      <td className="border-l border-border p-2 text-center">
        {streak > 0 && (
          <Badge className="border-transparent bg-primary/10 text-primary" variant="outline">
            {streak} {streak === 1 ? "DAY" : "DAYS"}
          </Badge>
        )}
      </td>
      <td className="border-l border-border p-1 text-center">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              aria-label={`Actions for ${habit.name}`}
              className="touch-target opacity-0 transition-opacity duration-fast group-hover:opacity-100 focus-visible:opacity-100 data-[state=open]:opacity-100"
              size="icon"
              variant="ghost"
            >
              <MoreHorizontal aria-hidden className="size-4" />
            </Button>
          </DropdownMenuTrigger>
          {/* Portal-rendered to document.body, outside .habits-journal — the
              scoped theme class is repeated here so it still picks it up. */}
          <DropdownMenuContent align="end" className="habits-journal">
            <DropdownMenuItem onSelect={() => setCustomizeOpen(true)}>Customize icon &amp; tags</DropdownMenuItem>
            <DropdownMenuItem className="text-destructive focus:text-destructive" onSelect={() => onDelete(habit.id)}>
              Delete
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
        <HabitCustomizeDialog
          habit={habit}
          open={customizeOpen}
          onOpenChange={setCustomizeOpen}
          onSave={(icon, tags) => onCustomize(habit.id, icon, tags)}
        />
      </td>
    </tr>
  );
}
