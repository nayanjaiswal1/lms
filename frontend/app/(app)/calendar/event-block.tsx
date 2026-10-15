"use client";

import { Button } from "@/components/ui/button";
import type { CSSProperties } from "react";
import { formatTimeLabel } from "@/app/(app)/calendar/calendar-math";
import { CALENDAR_LAYER_OPTIONS, CALENDAR_PRIORITY_OPTIONS } from "@/lib/calendar/types";
import type { CalendarEvent, CalendarLayer } from "@/lib/calendar/types";
import { Checkbox } from "@/components/ui/checkbox";
import { cn } from "@/lib/utils";

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

export function layerMetaFor(layer: CalendarLayer) {
  return CALENDAR_LAYER_OPTIONS.find((l) => l.value === layer) ?? CALENDAR_LAYER_OPTIONS[0];
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
  const meta = layerMetaFor(layer);
  const start = new Date(event.starts_at);
  const end = event.ends_at ? new Date(event.ends_at) : null;
  const cancelled = event.status === "cancelled";
  const completed = Boolean(event.completed_at);
  const dimmed = cancelled || completed ? "opacity-60 line-through" : "";
  const priorityMeta = event.priority ? CALENDAR_PRIORITY_OPTIONS.find((p) => p.value === event.priority) : undefined;
  const timeLabel = event.all_day ? "All day" : formatTimeLabel(start);
  const handleClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    onClick();
  };

  if (variant === "agenda") {
    // Checkbox sits beside (not inside) the row button so the two controls
    // are separate tab stops and the checkbox gets its own 44px hit area.
    return (
      <div className="flex items-center gap-1 rounded-md transition-colors duration-fast ease-smooth hover:bg-muted">
        {onToggleComplete ? (
          <label className="touch-target shrink-0 cursor-pointer" htmlFor={`done-${event.id}`}>
            <Checkbox
              aria-label={completed ? `Mark "${event.title}" not done` : `Mark "${event.title}" done`}
              checked={completed}
              className="h-5 w-5"
              id={`done-${event.id}`}
              onCheckedChange={(v) => onToggleComplete(v === true)}
            />
          </label>
        ) : (
          <span aria-hidden className="flex w-11 shrink-0 justify-center">
            <span className={cn("h-8 w-1 rounded-pill", meta.swatchClassName)} />
          </span>
        )}
        <Button
          className={cn("flex min-h-11 min-w-0 flex-1 items-center gap-3 py-2 pr-3 text-left text-sm", dimmed)}
          type="button"
          variant="unstyled"
          onClick={handleClick}
        >
          <span className="w-16 shrink-0 text-xs tabular-nums text-muted-foreground sm:w-20">
            {timeLabel}
            {!event.all_day && end && <span className="block opacity-80">{formatTimeLabel(end)}</span>}
          </span>
          <span className="flex min-w-0 flex-1 flex-col">
            <span className="truncate font-medium text-foreground">{event.title}</span>
            <span className="truncate text-xs text-muted-foreground">{meta.label}</span>
          </span>
          {priorityMeta && (
            <span className={cn("h-2 w-2 shrink-0 rounded-full", priorityMeta.swatchClassName)} title={`Priority: ${priorityMeta.label}`}>
              <span className="sr-only">Priority: {priorityMeta.label}</span>
            </span>
          )}
        </Button>
      </div>
    );
  }

  if (variant === "month") {
    return (
      <Button
        className={cn(
          "relative flex w-full items-center overflow-hidden rounded-sm border py-0.5 pl-2 pr-1.5 text-left text-xs",
          meta.badgeClassName,
          dimmed,
        )}
        draggable={draggable}
        title={`${timeLabel} · ${event.title}`}
        type="button"
        variant="unstyled"
        onClick={handleClick}
        onDragStart={onDragStart}
      >
        <span aria-hidden className={cn("absolute inset-y-0 left-0 w-0.5", meta.swatchClassName)} />
        <span className="truncate">
          {!event.all_day && <span className="mr-1 tabular-nums opacity-80">{formatTimeLabel(start)}</span>}
          <span className="font-medium">{event.title}</span>
        </span>
      </Button>
    );
  }

  // variant === "time" — absolutely positioned inside a day column.
  return (
    <div
      className={cn(
        "group absolute inset-x-0.5 z-raised flex flex-col overflow-hidden rounded-md border pl-2.5 pr-1.5 text-xs shadow-raised",
        meta.badgeClassName,
        dimmed,
      )}
      draggable={draggable}
      style={style}
      onDragStart={onDragStart}
    >
      <span aria-hidden className={cn("absolute inset-y-0 left-0 w-1", meta.swatchClassName)} />
      <Button
        className="flex min-h-0 flex-1 flex-col items-start overflow-hidden py-1 text-left"
        type="button"
        variant="unstyled"
        onClick={handleClick}
      >
        {/* shrink-0 on both lines: without it, a flex-col button shorter than
            two line-heights (any event under ~30min at this PX_PER_HOUR)
            squeezes each span's box toward zero instead of just clipping the
            overflow, rendering the title as a near-invisible sliver. */}
        <span className="w-full shrink-0 truncate font-semibold">{event.title}</span>
        <span className="shrink-0 tabular-nums opacity-80">
          {formatTimeLabel(start)}
          {end && <span className="hidden sm:inline"> – {formatTimeLabel(end)}</span>}
        </span>
      </Button>
      {resizeHandlers && !cancelled && (
        <div
          aria-hidden
          className="absolute inset-x-0 bottom-0 flex h-2 cursor-ns-resize touch-none justify-center opacity-0 transition-opacity duration-fast group-hover:opacity-100"
          onPointerDown={(e) => {
            e.currentTarget.setPointerCapture(e.pointerId);
            resizeHandlers.onPointerDown(e);
          }}
          onPointerMove={resizeHandlers.onPointerMove}
          onPointerUp={resizeHandlers.onPointerUp}
        >
          <span className="mt-0.5 h-1 w-6 rounded-pill bg-current opacity-50" />
        </div>
      )}
    </div>
  );
}
