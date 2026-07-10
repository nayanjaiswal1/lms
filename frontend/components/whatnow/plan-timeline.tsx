"use client";

// The day timeline — an hour grid where scheduled tasks render as absolutely
// positioned blocks. Drop targets accept drags from the backlog, the inbox,
// or another slot on this same grid (a move). Mirrors the structure of
// calendar/time-grid-view.tsx: PX_PER_HOUR pixel math, native HTML5 drag for
// move, pointer events for resize.

import * as React from "react";
import { Button } from "@/components/ui/button";
import { PlanBlock } from "@/components/whatnow/plan-block";
import { TASK_DRAG_MIME, TASK_SOURCE_MIME } from "@/components/whatnow/plan-backlog";
import {
  PX_PER_HOUR,
  dateAtMinutes,
  formatTimeLabel,
  minutesSinceMidnight,
  snapMinutes,
  startOfDay,
} from "@/lib/whatnow/day-math";
import type { PlanTask, SchedulePatch } from "@/lib/server/whatnow";

const HOURS = Array.from({ length: 24 }, (_, h) => h);

interface ResizePreview {
  taskId: string;
  deltaMinutes: number;
}

interface PlanTimelineProps {
  date: string;
  tasks: PlanTask[];
  resizePreview: ResizePreview | null;
  onNavigate: (direction: 1 | -1) => void;
  onSchedule: (taskId: string, patch: SchedulePatch) => void;
  onResizeStart: (taskId: string) => void;
  onResizeMove: (deltaMinutes: number) => void;
  onResizeEnd: () => void;
}

export function PlanTimeline({
  date,
  tasks,
  resizePreview,
  onNavigate,
  onSchedule,
  onResizeStart,
  onResizeMove,
  onResizeEnd,
}: PlanTimelineProps) {
  const dayStart = startOfDay(new Date(`${date}T00:00:00`));
  const resizeOrigin = React.useRef<{ clientY: number; originDurationMin: number } | null>(null);

  function minutesFromPointer(container: HTMLElement, clientY: number): number {
    const rect = container.getBoundingClientRect();
    return snapMinutes(((clientY - rect.top) / PX_PER_HOUR) * 60);
  }

  function makeResizeHandlers(task: PlanTask) {
    return {
      onPointerDown: (e: React.PointerEvent) => {
        resizeOrigin.current = { clientY: e.clientY, originDurationMin: task.durationMin ?? 30 };
        onResizeStart(task.id);
      },
      onPointerMove: (e: React.PointerEvent) => {
        if (!resizeOrigin.current) return;
        onResizeMove(snapMinutes(((e.clientY - resizeOrigin.current.clientY) / PX_PER_HOUR) * 60));
      },
      onPointerUp: (e: React.PointerEvent) => {
        if (!resizeOrigin.current) return;
        const deltaMinutes = snapMinutes(((e.clientY - resizeOrigin.current.clientY) / PX_PER_HOUR) * 60);
        const durationMin = Math.max(15, resizeOrigin.current.originDurationMin + deltaMinutes);
        onSchedule(task.id, { durationMin });
        resizeOrigin.current = null;
        onResizeEnd();
      },
    };
  }

  return (
    <div className="w-full min-w-0 flex-1 overflow-hidden rounded-lg border border-border">
      <div className="flex items-center justify-between border-b border-border px-3 py-2">
        <Button size="sm" variant="ghost" onClick={() => onNavigate(-1)}>
          ← Prev
        </Button>
        <p className="text-sm font-semibold tabular-nums">{date}</p>
        <Button size="sm" variant="ghost" onClick={() => onNavigate(1)}>
          Next →
        </Button>
      </div>

      <div className="relative h-[70vh] overflow-y-auto">
        {/* eslint-disable-next-line no-restricted-syntax -- total-day height is computed from PX_PER_HOUR, not expressible as a static token */}
        <div className="relative" style={{ height: `${24 * PX_PER_HOUR}px` }}>
          {HOURS.map((h) => (
            <div
              className="absolute inset-x-0 border-t border-border/60"
              key={h}
              // eslint-disable-next-line no-restricted-syntax -- hour gridline offset is computed from PX_PER_HOUR, not expressible as a static token
              style={{ top: `${h * PX_PER_HOUR}px` }}
            >
              <span className="absolute -translate-y-1/2 pl-2 text-xs text-muted-foreground">
                {h === 0 ? "" : new Date(2000, 0, 1, h).toLocaleTimeString(undefined, { hour: "numeric" })}
              </span>
            </div>
          ))}

          <div
            className="absolute inset-0 ml-14"
            onDragOver={(e) => e.preventDefault()}
            onDrop={(e) => {
              e.preventDefault();
              const taskId = e.dataTransfer.getData(TASK_DRAG_MIME);
              if (!taskId) return;
              const source = e.dataTransfer.getData(TASK_SOURCE_MIME);
              const minutes = minutesFromPointer(e.currentTarget, e.clientY);
              onSchedule(taskId, {
                scheduledStart: dateAtMinutes(dayStart, minutes).toISOString(),
                ...(source === "inbox" ? { status: "planned" as const } : {}),
              });
            }}
          >
            {tasks.map((task) => {
              const start = task.scheduledStart ? new Date(task.scheduledStart) : dayStart;
              const startMinutes = minutesSinceMidnight(start);
              let durationMinutes = task.durationMin ?? 30;
              if (resizePreview?.taskId === task.id) {
                durationMinutes = Math.max(15, durationMinutes + resizePreview.deltaMinutes);
              }
              const top = (startMinutes / 60) * PX_PER_HOUR;
              const height = Math.max(20, (durationMinutes / 60) * PX_PER_HOUR);

              return (
                <PlanBlock
                  key={task.id}
                  resizeHandlers={makeResizeHandlers(task)}
                  // eslint-disable-next-line no-restricted-syntax -- computed pixel position/height is inherently dynamic, no token can express it
                  style={{ top: `${top}px`, height: `${height}px` }}
                  task={task}
                  timeLabel={formatTimeLabel(start)}
                  onDragStart={(e) => {
                    e.dataTransfer.setData(TASK_DRAG_MIME, task.id);
                    e.dataTransfer.setData(TASK_SOURCE_MIME, "scheduled");
                    e.dataTransfer.effectAllowed = "move";
                  }}
                  onUnschedule={() => onSchedule(task.id, { scheduledStart: null })}
                />
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
