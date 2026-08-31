"use client";

import { useState, useTransition } from "react";

import { Checkbox } from "@/components/ui/checkbox";
import { completeTaskAction, type PlanTask } from "@/lib/server/whatnow";

interface DiaryTodayListsProps {
  tasks: PlanTask[];
}

// Read-only projection of the user's real What Now? inbox onto the diary's
// "To-Do" / "Buy List" sections — no diary-owned task data. Checking a box
// completes the real whatnow task via the existing complete endpoint.
export function DiaryTodayLists({ tasks }: DiaryTodayListsProps) {
  const [doneIds, setDoneIds] = useState<Set<string>>(new Set());
  const [, startTransition] = useTransition();

  const visible = tasks.filter((t) => !doneIds.has(t.id));
  const buyItems = visible.filter((t) => t.category === "buy");
  const todoItems = visible.filter((t) => t.category !== "buy");

  function handleCheck(id: string) {
    setDoneIds((prev) => new Set(prev).add(id));
    startTransition(async () => {
      await completeTaskAction(id);
    });
  }

  return (
    <div className="flex flex-col gap-6">
      <TaskSection items={todoItems} title="To-Do" onCheck={handleCheck} />
      <TaskSection items={buyItems} title="Buy List" onCheck={handleCheck} />
    </div>
  );
}

interface TaskSectionProps {
  title: string;
  items: PlanTask[];
  onCheck: (id: string) => void;
}

function TaskSection({ title, items, onCheck }: TaskSectionProps) {
  if (items.length === 0) return null;
  return (
    <div className="border-t border-border pt-4">
      <h3 className="diary-paper-headline mb-3 text-lg font-semibold text-foreground">{title}</h3>
      <ul className="flex flex-col gap-2">
        {items.map((task) => (
          <li className="flex items-center gap-2.5" key={task.id}>
            <Checkbox id={`diary-task-${task.id}`} onCheckedChange={() => onCheck(task.id)} />
            <label className="text-sm text-foreground" htmlFor={`diary-task-${task.id}`}>
              {task.title}
            </label>
          </li>
        ))}
      </ul>
    </div>
  );
}
