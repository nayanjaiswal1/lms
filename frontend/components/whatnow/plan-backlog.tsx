"use client";

// The unscheduled backlog — drag to rank (persisted as plan_position via
// onReorder), drag onto the timeline to time-block. The Inbox section lets a
// task join the plan without leaving this page.

import { useState } from "react";
import { Button } from "@/components/ui/button";
import type { PlanTask } from "@/lib/server/whatnow";

export const TASK_DRAG_MIME = "text/whatnow-task-id";
export const TASK_SOURCE_MIME = "text/whatnow-task-source";

interface PlanBacklogProps {
  tasks: PlanTask[];
  inbox: PlanTask[];
  onReorder: (next: PlanTask[]) => void;
  onPlanInboxTask: (task: PlanTask) => void;
  onUnschedule: (taskId: string) => void;
}

export function PlanBacklog({ tasks, inbox, onReorder, onPlanInboxTask, onUnschedule }: PlanBacklogProps) {
  const [dragId, setDragId] = useState<string | null>(null);

  function reorderOnto(targetId: string) {
    if (!dragId || dragId === targetId) return;
    const from = tasks.findIndex((t) => t.id === dragId);
    const to = tasks.findIndex((t) => t.id === targetId);
    if (from === -1 || to === -1) return;
    const next = [...tasks];
    const [moved] = next.splice(from, 1);
    next.splice(to, 0, moved);
    onReorder(next);
  }

  function dropFromTimeline(e: React.DragEvent): boolean {
    if (e.dataTransfer.getData(TASK_SOURCE_MIME) !== "scheduled") return false;
    const id = e.dataTransfer.getData(TASK_DRAG_MIME);
    if (!id) return false;
    onUnschedule(id);
    return true;
  }

  return (
    <section
      aria-label="Unscheduled backlog"
      className="card-base p-4"
      onDragOver={(e) => e.preventDefault()}
      onDrop={(e) => {
        e.preventDefault();
        dropFromTimeline(e);
      }}
    >
      <h2 className="section-title mb-1 text-base">Backlog</h2>
      <p className="mb-3 text-xs text-muted-foreground">
        Drag to rank, drag onto the timeline to block time.
      </p>

      {tasks.length === 0 ? (
        <p className="empty-state text-sm">Drag a block back here to unschedule it.</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {tasks.map((task) => (
            <li
              key={task.id}
              className="card-interactive cursor-grab touch-none rounded-md border border-border bg-card p-2.5 text-sm active:cursor-grabbing"
              draggable
              onDragEnd={() => setDragId(null)}
              onDragOver={(e) => e.preventDefault()}
              onDragStart={(e) => {
                setDragId(task.id);
                e.dataTransfer.setData(TASK_DRAG_MIME, task.id);
                e.dataTransfer.setData(TASK_SOURCE_MIME, "backlog");
                e.dataTransfer.effectAllowed = "move";
              }}
              onDrop={(e) => {
                e.preventDefault();
                e.stopPropagation();
                if (dropFromTimeline(e)) return;
                reorderOnto(task.id);
              }}
            >
              <p className="font-medium text-foreground">{task.title}</p>
              {task.durationMin ? <p className="text-xs text-muted-foreground">{task.durationMin}m</p> : null}
            </li>
          ))}
        </ul>
      )}

      {inbox.length > 0 && (
        <>
          <h3 className="section-title mb-1 mt-4 text-sm">Inbox</h3>
          <ul className="flex flex-col gap-2">
            {inbox.map((task) => (
              <li
                key={task.id}
                className="flex items-center justify-between gap-2 rounded-md border border-border p-2 text-sm"
              >
                <span className="truncate text-foreground">{task.title}</span>
                <Button size="sm" variant="outline" onClick={() => onPlanInboxTask(task)}>
                  Plan it
                </Button>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  );
}
