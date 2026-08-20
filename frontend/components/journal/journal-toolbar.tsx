"use client";

import { useCallback, useRef, useState } from "react";
import type { PointerEvent as ReactPointerEvent, RefObject } from "react";
import { GripHorizontal, Minus, Sparkles, X } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { JournalCategoryChips } from "@/components/journal/journal-category-chips";
import { JournalEntryForm } from "@/components/journal/journal-entry-form";
import { JournalSearchBar } from "@/components/journal/journal-search-bar";
import { cn } from "@/lib/utils";
import type { JournalCategoryNode } from "@/lib/server/journal";

interface JournalToolbarProps {
  categories: JournalCategoryNode[];
}

// Quick-capture input replaces the old "Add Learning" button. Typing doesn't
// open the full form right away — it waits until the user pauses.
// Position/width stay fixed across both states; height is conditional (FLOATING_BOX_OPEN_CLASS)
// so the closed single-line input isn't stranded inside a tall empty box, and
// the open form still gets a bounded height for its flex-1 textarea to fill.
// Not LessonFloatingPanel here: that component intentionally auto-sizes to
// content, which is exactly what a fixed, equal-size box can't do.
const TYPING_PAUSE_MS = 800;
const FLOATING_BOX_CLASS =
  "fixed above-bottom-nav inset-x-24 sm:inset-x-auto sm:right-4 sm:left-auto sm:w-full sm:max-w-md " +
  "z-modal animate-in fade-in slide-in-from-bottom-4 duration-normal ease-smooth";
const FLOATING_BOX_OPEN_CLASS = "h-[30rem] max-h-[calc(100dvh-2rem)]";

interface DragState {
  startX: number;
  startY: number;
  originX: number;
  originY: number;
  minX: number;
  maxX: number;
  minY: number;
  maxY: number;
}

// Lets the user drag the box off its default corner anchor. Offset is a
// translate3d layered on top of the fixed position, clamped to the viewport
// at drag-start so it can never be dropped off-screen with no way back.
function useDraggableBox(boxRef: RefObject<HTMLDivElement | null>) {
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const drag = useRef<DragState | null>(null);

  const onPointerDown = useCallback(
    (e: ReactPointerEvent<HTMLDivElement>) => {
      const rect = boxRef.current?.getBoundingClientRect();
      if (!rect) return;
      e.currentTarget.setPointerCapture(e.pointerId);
      const baseLeft = rect.left - offset.x;
      const baseTop = rect.top - offset.y;
      drag.current = {
        startX: e.clientX,
        startY: e.clientY,
        originX: offset.x,
        originY: offset.y,
        minX: -baseLeft,
        maxX: window.innerWidth - rect.width - baseLeft,
        minY: -baseTop,
        maxY: window.innerHeight - rect.height - baseTop,
      };
    },
    [boxRef, offset],
  );

  const onPointerMove = useCallback((e: ReactPointerEvent<HTMLDivElement>) => {
    const d = drag.current;
    if (!d) return;
    setOffset({
      x: Math.min(d.maxX, Math.max(d.minX, d.originX + (e.clientX - d.startX))),
      y: Math.min(d.maxY, Math.max(d.minY, d.originY + (e.clientY - d.startY))),
    });
  }, []);

  const onPointerUp = useCallback(() => {
    drag.current = null;
  }, []);

  return { offset, dragHandleProps: { onPointerDown, onPointerMove, onPointerUp } };
}

const MIN_BOX_WIDTH = 320;
const MIN_BOX_HEIGHT = 240;
const RESIZE_MARGIN = 16;

interface ResizeState {
  startX: number;
  startY: number;
  startWidth: number;
  startHeight: number;
  maxWidth: number;
  maxHeight: number;
}

// Bottom-right corner handle, sized in raw px once the user grabs it — same
// clamp-at-drag-start approach as useDraggableBox so it can't grow past the
// viewport edge from its current position.
function useResizableBox(boxRef: RefObject<HTMLDivElement | null>) {
  const [size, setSize] = useState<{ width: number; height: number } | null>(null);
  const resize = useRef<ResizeState | null>(null);

  const onPointerDown = useCallback(
    (e: ReactPointerEvent<HTMLDivElement>) => {
      const rect = boxRef.current?.getBoundingClientRect();
      if (!rect) return;
      e.currentTarget.setPointerCapture(e.pointerId);
      e.stopPropagation();
      resize.current = {
        startX: e.clientX,
        startY: e.clientY,
        startWidth: rect.width,
        startHeight: rect.height,
        maxWidth: window.innerWidth - rect.left - RESIZE_MARGIN,
        maxHeight: window.innerHeight - rect.top - RESIZE_MARGIN,
      };
    },
    [boxRef],
  );

  const onPointerMove = useCallback((e: ReactPointerEvent<HTMLDivElement>) => {
    const r = resize.current;
    if (!r) return;
    e.stopPropagation();
    // Locked 1:1 — one delta drives both axes so width and height always
    // move together, instead of dragging into an arbitrary rectangle.
    const delta = Math.max(e.clientX - r.startX, e.clientY - r.startY);
    setSize({
      width: Math.min(r.maxWidth, Math.max(MIN_BOX_WIDTH, r.startWidth + delta)),
      height: Math.min(r.maxHeight, Math.max(MIN_BOX_HEIGHT, r.startHeight + delta)),
    });
  }, []);

  const onPointerUp = useCallback((e: ReactPointerEvent<HTMLDivElement>) => {
    resize.current = null;
    e.stopPropagation();
  }, []);

  const resetSize = useCallback(() => setSize(null), []);

  return { size, resetSize, resizeHandleProps: { onPointerDown, onPointerMove, onPointerUp } };
}

// Hide the box behind a small chat-launcher-style bubble; hovering the
// bubble previews the closed input via CSS (group-hover), clicking it pins
// the box back open — the hover preview alone wouldn't work on touch.
function useMinimizable() {
  const [minimized, setMinimized] = useState(false);
  return { minimized, hide: () => setMinimized(true), show: () => setMinimized(false) };
}

export function JournalToolbar({ categories }: JournalToolbarProps) {
  const [draftText, setDraftText] = useState("");
  const [open, setOpen] = useState(false);
  const pauseTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const boxRef = useRef<HTMLDivElement>(null);
  const { offset, dragHandleProps } = useDraggableBox(boxRef);
  const { size, resetSize, resizeHandleProps } = useResizableBox(boxRef);
  const { minimized, hide, show } = useMinimizable();

  function openBox() {
    setOpen(true);
    resetSize();
  }

  function onDraftChange(value: string) {
    setDraftText(value);
    clearTimeout(pauseTimer.current);
    if (!value.trim()) return;
    pauseTimer.current = setTimeout(openBox, TYPING_PAUSE_MS);
  }

  function close() {
    clearTimeout(pauseTimer.current);
    setOpen(false);
    setDraftText("");
  }

  return (
    <div className="mb-4 flex flex-col gap-3">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <JournalCategoryChips categories={categories} />
        <JournalSearchBar />
      </div>

      {minimized ? (
        <button
          aria-label="Show quick capture"
          className="group fixed above-bottom-nav right-4 z-modal flex size-11 touch-target items-center justify-center rounded-full border border-border bg-background shadow-raised transition-transform duration-fast ease-smooth hover:scale-105"
          type="button"
          onClick={show}
        >
          <Sparkles aria-hidden className="size-4 text-ai" />
          <span
            aria-hidden
            className="pointer-events-none absolute bottom-full right-0 mb-2 w-56 origin-bottom-right scale-95 rounded-lg border border-border bg-background p-3 text-left text-xs text-muted-foreground opacity-0 shadow-raised transition duration-fast ease-smooth group-hover:scale-100 group-hover:opacity-100"
          >
            What did you learn today?
          </span>
        </button>
      ) : (
        <div
          ref={boxRef}
          aria-label="Add a journal entry"
          className={cn(FLOATING_BOX_CLASS, open && FLOATING_BOX_OPEN_CLASS)}
          role="dialog"
          style={{
            transform: `translate3d(${offset.x}px, ${offset.y}px, 0)`,
            ...(size ? { width: size.width, height: size.height, maxWidth: "none", maxHeight: "none" } : {}),
          }}
        >
          <div className="relative flex h-full flex-col overflow-hidden rounded-xl border border-border bg-background shadow-raised">
            <div
              {...dragHandleProps}
              aria-label="Drag to move"
              className="flex h-4 shrink-0 cursor-grab touch-none items-center justify-center bg-muted/40 active:cursor-grabbing"
              role="button"
              tabIndex={-1}
            >
              <GripHorizontal aria-hidden className="size-3.5 text-muted-foreground" />
              <button
                aria-label="Hide"
                className="absolute right-0.5 flex size-3.5 items-center justify-center text-muted-foreground hover:text-foreground"
                type="button"
                onClick={hide}
                onPointerDown={(e) => e.stopPropagation()}
              >
                <Minus aria-hidden className="size-3" />
              </button>
            </div>
            {open ? (
              <>
                <div className="flex shrink-0 items-center justify-between border-b border-border px-4 py-3">
                  <div className="flex items-center gap-2">
                    <Sparkles aria-hidden className="size-4 text-ai" />
                    <span className="text-sm font-medium">Add Learning</span>
                  </div>
                  <Button
                    aria-label="Close"
                    className="touch-target size-7"
                    size="icon"
                    variant="ghost"
                    onClick={close}
                  >
                    <X aria-hidden className="size-3.5" />
                  </Button>
                </div>
                <div className="flex min-h-0 flex-1 flex-col px-4 py-3">
                  <JournalEntryForm contentAutoFocus categories={categories} draft={{ content: draftText }} onSaved={close} />
                </div>
              </>
            ) : (
              <div className="relative flex-1">
                <Textarea
                  className="touch-target h-full min-h-48 resize-none rounded-none border-0 text-base focus-visible:ring-0 focus-visible:ring-offset-0"
                  placeholder="What did you learn today?"
                  rows={1}
                  value={draftText}
                  onChange={(e) => onDraftChange(e.target.value)}
                />
                <div
                  {...resizeHandleProps}
                  aria-label="Resize"
                  className="absolute bottom-0 right-0 size-4 cursor-nwse-resize touch-none text-muted-foreground/50"
                  role="button"
                  tabIndex={-1}
                >
                  <GripHorizontal aria-hidden className="absolute bottom-0.5 right-0.5 size-3 rotate-45" />
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
