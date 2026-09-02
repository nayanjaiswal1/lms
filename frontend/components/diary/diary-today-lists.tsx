"use client";

import { useMemo, useState, useTransition } from "react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { cn } from "@/lib/utils";
import { toggleDiaryTaskAction } from "@/app/(app)/diary/actions";
import type { DiaryGoal, DiaryTask } from "@/lib/server/diary";

interface DiaryTodayListsProps {
  tasks: DiaryTask[];
  goals: DiaryGoal[];
}

// Diary's own todo/buy checklist (diary_tasks — no dependency on What Now?)
// plus a read-only "Goals" strip (daily/weekly/monthly habits, joined from
// habit.Service.MonthView server-side — see internal/diary/handler.go's
// withGoals). Checking a task crosses it out instead of removing it; tags
// filter which tasks show.
export function DiaryTodayLists({ tasks, goals }: DiaryTodayListsProps) {
  const [items, setItems] = useState(tasks);
  const [activeTag, setActiveTag] = useState<string | null>(null);
  const [, startTransition] = useTransition();

  const allTags = useMemo(() => Array.from(new Set(items.flatMap((t) => t.tags))).sort(), [items]);
  const visible = activeTag ? items.filter((t) => t.tags.includes(activeTag)) : items;
  const buyItems = visible.filter((t) => t.kind === "buy");
  const todoItems = visible.filter((t) => t.kind === "todo");

  function handleCheck(id: string, done: boolean) {
    setItems((prev) => prev.map((t) => (t.id === id ? { ...t, done } : t)));
    startTransition(async () => {
      await toggleDiaryTaskAction(id, done);
    });
  }

  return (
    <div className="flex flex-col gap-6">
      {goals.length > 0 && (
        <div>
          <h3 className="diary-paper-headline mb-3 text-lg font-semibold text-foreground">Goals</h3>
          <ul className="flex flex-col gap-1.5">
            {goals.map((g) => (
              <li className="flex items-center gap-2 text-sm" key={g.id}>
                <span className={cn("size-1.5 rounded-full", g.done ? "bg-primary" : "bg-muted-foreground/40")} />
                <span className={cn(g.done && "text-muted-foreground line-through")}>{g.name}</span>
                <Badge className="ml-auto" variant="outline">
                  {g.cadence}
                </Badge>
              </li>
            ))}
          </ul>
        </div>
      )}

      {allTags.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          <Button
            aria-pressed={activeTag === null}
            className={cn("touch-target px-2.5 text-xs", activeTag === null && "bg-accent")}
            size="sm"
            type="button"
            variant="ghost"
            onClick={() => setActiveTag(null)}
          >
            All
          </Button>
          {allTags.map((tag) => (
            <Button
              aria-pressed={activeTag === tag}
              className={cn("touch-target px-2.5 text-xs", activeTag === tag && "bg-accent text-primary")}
              key={tag}
              size="sm"
              type="button"
              variant="ghost"
              onClick={() => setActiveTag(tag)}
            >
              {tag}
            </Button>
          ))}
        </div>
      )}

      <TaskSection items={todoItems} title="To-Do" onCheck={handleCheck} />
      <TaskSection items={buyItems} title="Buy List" onCheck={handleCheck} />
    </div>
  );
}

interface TaskSectionProps {
  title: string;
  items: DiaryTask[];
  onCheck: (id: string, done: boolean) => void;
}

function TaskSection({ title, items, onCheck }: TaskSectionProps) {
  if (items.length === 0) return null;
  return (
    <div className="border-t border-border pt-4">
      <h3 className="diary-paper-headline mb-3 text-lg font-semibold text-foreground">{title}</h3>
      <ul className="flex flex-col gap-2">
        {items.map((task) => (
          <li className="flex items-center gap-2.5" key={task.id}>
            <Checkbox
              checked={task.done}
              id={`diary-task-${task.id}`}
              onCheckedChange={(checked) => onCheck(task.id, checked === true)}
            />
            <label
              className={cn("text-sm text-foreground", task.done && "text-muted-foreground line-through")}
              htmlFor={`diary-task-${task.id}`}
            >
              {task.title}
            </label>
          </li>
        ))}
      </ul>
    </div>
  );
}
