"use client";

import type { CSSProperties } from "react";
import { formatTimeLabel } from "@/app/(app)/calendar/calendar-math";
import { CALENDAR_LAYER_OPTIONS } from "@/lib/calendar/types";
import type { CalendarEvent, CalendarLayer } from "@/lib/calendar/types";

/** Picks the first matching layer's swatch/badge so an event that belongs to
 * more than one layer (e.g. a mentor session that's also "mine") still gets
 * one consistent, legible color instead of blending several. */
export function primaryLayerFor(event: CalendarEvent, currentUserId: string): CalendarLayer {
  if (event.event_type === "mentor_session") return "mentor";
  if (event.is_virtual) return "assessment";
  if (event.course_id) return "course";
  if (event.batch_id) return "batch";
  return event.created_by === currentUserId ? "mine" : "batch";
}

export interface ResizeHandlers {
  onPointerDown: (e: React.PointerEvent) => void;
  onPointerMove: (e: React.PointerEvent) => void;
  onPointerUp: (e: React.PointerEvent) => void;
}

interface EventBlockProps {
  event: CalendarEvent;
  layer: CalendarLayer;
  variant: "month" | "time" | "agenda";
  style?: CSSProperties;
  draggable?: boolean;
  onClick: () => void;
  onDragStart?: (e: React.DragEvent) => void;
  resizeHandlers?: ResizeHandlers;
  // Task events only — presence of this prop (rather than event_type) is what
  // decides whether a checkbox renders, so non-task callers never pass it.
  onToggleComplete?: (completed: boolean) => void;
}

export function EventBlock({
  event,
  layer,
  variant,
  style,
  draggable = false,
  onClick,
  onDragStart,
  resizeHandlers,
  onToggleComplete,
}: EventBlockProps) {
  const meta = CALENDAR_LAYER_OPTIONS.find((l) => l.value === layer) ?? CALENDAR_LAYER_OPTIONS[0];
  const start = new Date(event.starts_at);
  const cancelled = event.status === "cancelled";
  const completed = Boolean(event.completed_at);

  const base = `group relative flex cursor-pointer flex-col gap-0.5 overflow-hidden rounded-md border px-2 py-1 text-left text-xs transition-colors duration-fast ease-smooth ${meta.badgeClassName} ${
    cancelled || completed ? "opacity-50 line-through" : ""
  }`;

  if (variant === "agenda") {
    return (
      <button
        className={`${base} w-full flex-row items-center gap-2 py-2`}
        type="button"
        onClick={(e) => {
          e.stopPropagation();
          onClick();
        }}
      >
        {onToggleComplete ? (
          <input
            aria-label={completed ? "Mark task not done" : "Mark task done"}
            checked={completed}
            className="h-4 w-4 shrink-0"
            type="checkbox"
            onChange={(e) => onToggleComplete(e.target.checked)}
            onClick={(e) => e.stopPropagation()}
          />
        ) : (
          <span aria-hidden className={`h-2 w-2 shrink-0 rounded-full ${meta.swatchClassName}`} />
        )}
        <span className="shrink-0 tabular-nums text-muted-foreground">
          {event.all_day ? "All day" : formatTimeLabel(start)}
        </span>
        <span className="truncate font-medium text-foreground">{event.title}</span>
      </button>
    );
  }

  if (variant === "month") {
    return (
      <button
        className={`${base} w-full truncate`}
        draggable={draggable}
        title={event.title}
        type="button"
        onClick={(e) => {
          e.stopPropagation();
          onClick();
        }}
        onDragStart={onDragStart}
      >
        <span className="truncate">
          {!event.all_day && <span className="mr-1 tabular-nums opacity-80">{formatTimeLabel(start)}</span>}
          {event.title}
        </span>
      </button>
    );
  }

  // variant === "time" — absolutely positioned inside a day column.
  return (
    <div
      className={`${base} absolute inset-x-0.5 z-raised`}
      draggable={draggable}
      style={style}
      onDragStart={onDragStart}
    >
      <button
        className="flex min-h-0 flex-1 flex-col items-start overflow-hidden text-left"
        type="button"
        onClick={(e) => {
          e.stopPropagation();
          onClick();
        }}
      >
        {/* shrink-0 on both lines: without it, a flex-col button shorter than
            two line-heights (any event under ~30min at this PX_PER_HOUR)
            squeezes each span's box toward zero instead of just clipping the
            overflow, rendering the title as a near-invisible sliver. */}
        <span className="truncate shrink-0 font-medium">{event.title}</span>
        <span className="shrink-0 tabular-nums opacity-80">{formatTimeLabel(start)}</span>
      </button>
      {resizeHandlers && !cancelled && (
        <div
          aria-hidden
          className="absolute inset-x-0 bottom-0 h-1.5 cursor-ns-resize touch-none bg-current opacity-0 group-hover:opacity-100"
          onPointerDown={(e) => {
            e.currentTarget.setPointerCapture(e.pointerId);
            resizeHandlers.onPointerDown(e);
          }}
          onPointerMove={resizeHandlers.onPointerMove}
          onPointerUp={resizeHandlers.onPointerUp}
        />
      )}
    </div>
  );
}
