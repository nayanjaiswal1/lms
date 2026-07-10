"use client";

// One scheduled task's time block on the Plan Day timeline. Presentational —
// PlanTimeline owns the pixel math and resize/drag commit logic, mirroring
// calendar/event-block.tsx's "time" variant.

import type { CSSProperties } from "react";
import type { PlanTask } from "@/lib/server/whatnow";

export interface ResizeHandlers {
  onPointerDown: (e: React.PointerEvent) => void;
  onPointerMove: (e: React.PointerEvent) => void;
  onPointerUp: (e: React.PointerEvent) => void;
}

interface PlanBlockProps {
  task: PlanTask;
  style: CSSProperties;
  timeLabel: string;
  resizeHandlers: ResizeHandlers;
  onDragStart: (e: React.DragEvent) => void;
  onUnschedule: () => void;
}

export function PlanBlock({ task, style, timeLabel, resizeHandlers, onDragStart, onUnschedule }: PlanBlockProps) {
  return (
    <div
      className="group absolute inset-x-0.5 z-raised flex flex-col gap-0.5 overflow-hidden rounded-md border border-primary/40 bg-primary/10 px-2 py-1 text-left text-xs"
      draggable
      style={style}
      onDragStart={onDragStart}
    >
      <button
        aria-label={`Unschedule ${task.title}`}
        className="absolute right-1 top-1 hidden h-4 w-4 items-center justify-center rounded-full bg-background text-muted-foreground group-hover:flex"
        type="button"
        onClick={(e) => {
          e.stopPropagation();
          onUnschedule();
        }}
      >
        ×
      </button>
      <span className="truncate shrink-0 font-medium text-foreground">{task.title}</span>
      <span className="shrink-0 tabular-nums text-muted-foreground">{timeLabel}</span>
      <div
        aria-hidden
        className="absolute inset-x-0 bottom-0 h-1.5 cursor-ns-resize touch-none bg-primary opacity-0 group-hover:opacity-100"
        onPointerDown={(e) => {
          e.currentTarget.setPointerCapture(e.pointerId);
          resizeHandlers.onPointerDown(e);
        }}
        onPointerMove={resizeHandlers.onPointerMove}
        onPointerUp={resizeHandlers.onPointerUp}
      />
    </div>
  );
}
