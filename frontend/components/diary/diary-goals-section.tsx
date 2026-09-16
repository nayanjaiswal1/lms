"use client";

import { Trash2 } from "lucide-react";
import { useState, useTransition } from "react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { cn } from "@/lib/utils";
import { createDiaryGoalAction, deleteDiaryGoalAction, toggleDiaryGoalAction } from "@/app/(app)/diary/actions";
import type { DiaryGoal } from "@/lib/server/diary";
import type { HabitCadence } from "@/lib/server/habits";

interface DiaryGoalsSectionProps {
  date: string;
  goals: DiaryGoal[];
}

// A goal IS a habit (see GoalStatus in internal/diary/models.go) — this
// gives the diary page its own create/complete/remove affordances over the
// same habit.Service endpoints the Habits page uses, so the writer never
// has to leave the page to log a new intention or check one off.
export function DiaryGoalsSection({ date, goals: initial }: DiaryGoalsSectionProps) {
  const [goals, setGoals] = useState(initial);
  const [, startTransition] = useTransition();

  function toggle(id: string, period: string, done: boolean) {
    setGoals((prev) => prev.map((g) => (g.id === id ? { ...g, done } : g)));
    startTransition(async () => {
      await toggleDiaryGoalAction(id, period, done);
    });
  }

  function add(name: string, cadence: HabitCadence) {
    startTransition(async () => {
      const { ok, data } = await createDiaryGoalAction(date, name, cadence);
      if (ok && data) setGoals(data.goals);
    });
  }

  function remove(id: string) {
    setGoals((prev) => prev.filter((g) => g.id !== id));
    startTransition(async () => {
      await deleteDiaryGoalAction(id);
    });
  }

  return (
    <div>
      <h3 className="diary-paper-headline mb-3 text-lg font-semibold text-foreground">Goals</h3>
      <ul className="flex flex-col gap-1.5">
        {goals.map((g) => (
          <li className="group flex items-center gap-2 text-sm" key={g.id}>
            <Checkbox
              checked={g.done}
              id={`diary-goal-${g.id}`}
              onCheckedChange={(checked) => toggle(g.id, g.period, checked === true)}
            />
            <label className={cn("flex-1", g.done && "text-muted-foreground line-through")} htmlFor={`diary-goal-${g.id}`}>
              {g.name}
            </label>
            <Badge variant="outline">{g.cadence}</Badge>
            <Button
              aria-label={`Remove goal ${g.name}`}
              className="size-6 opacity-0 group-hover:opacity-100"
              size="icon"
              type="button"
              variant="ghost"
              onClick={() => remove(g.id)}
            >
              <Trash2 aria-hidden className="size-3.5 text-destructive" />
            </Button>
          </li>
        ))}
        <AddGoalRow onAdd={add} />
      </ul>
    </div>
  );
}

const GOAL_CADENCES: HabitCadence[] = ["daily", "weekly", "monthly"];

interface AddGoalRowProps {
  onAdd: (name: string, cadence: HabitCadence) => void;
}

// Deliberately minimal next to AddHabitInline's full dialog (type/custom
// fields/weekday picker) — the diary strip only ever needs a name and a
// cadence to plant a new goal; anything more structured (gym/sleep/reading
// entry forms, weekday-specific weekly goals) is still a trip to the Habits
// page, same as before this existed.
function AddGoalRow({ onAdd }: AddGoalRowProps) {
  const [name, setName] = useState("");
  const [cadence, setCadence] = useState<HabitCadence>("daily");

  function submit() {
    const trimmed = name.trim();
    if (trimmed === "") return;
    onAdd(trimmed, cadence);
    setName("");
  }

  return (
    <li className="flex items-center gap-2">
      <Input
        className="flex-1 text-sm"
        placeholder="Add a goal…"
        value={name}
        onChange={(e) => setName(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            e.preventDefault();
            submit();
          }
        }}
      />
      <Select value={cadence} onValueChange={(value: HabitCadence) => setCadence(value)}>
        <SelectTrigger aria-label="Goal cadence" className="h-8 w-24 text-xs">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {GOAL_CADENCES.map((c) => (
            <SelectItem key={c} value={c}>
              {c}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      <Button size="sm" type="button" variant="ghost" onClick={submit}>
        Add
      </Button>
    </li>
  );
}
