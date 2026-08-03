"use client";

import { useRef, useState } from "react";
import { Crosshair, Maximize2, Minimize2, Plus, ZoomIn, ZoomOut } from "lucide-react";
import { parseAsString, useQueryState } from "nuqs";
import { toast } from "sonner";
import { CategoryTabs } from "@/components/focus-wall/category-tabs";
import { Button } from "@/components/ui/button";
import { StickyNote } from "@/components/focus-wall/sticky-note";
import { useFocusCategories } from "@/components/focus-wall/use-focus-categories";
import { useFullscreen } from "@/components/focus-wall/use-fullscreen";
import { createNoteAction, deleteNoteAction, updateNoteAction } from "@/app/(app)/focus-wall/actions";
import type { FocusCategory, FocusNote } from "@/lib/server/focus-wall";
import { NOTE_CATEGORY, NOTE_COLOR_OPTIONS } from "@/lib/constants";
import { cn } from "@/lib/utils";
import styles from "./focus-wall.module.css";

const ZOOM_MIN = 0.5;
const ZOOM_MAX = 1.5;
const ZOOM_STEP = 0.1;

// The corkboard's scrollable size is derived from where notes actually are,
// floored at these minimums (comfortably narrower/shorter than a typical
// desktop content area) so a wall with only a couple of notes near the top
// shows no scrollbar at all — a fixed oversized canvas would otherwise force
// one even when there's nothing to scroll to. Grows to fit once notes get
// dragged further out, still paired with the scroll spacer below so native
// scrolling reaches zoomed-in content (a bare `transform: scale` alone
// doesn't grow the scrollable area).
const CANVAS_MIN_WIDTH = 1000;
const CANVAS_MIN_HEIGHT = 800;
const CANVAS_MARGIN = 200;
const NOTE_WIDTH = 256; // w-64
const NOTE_MIN_HEIGHT = 160; // min-h-40

// The master pin the red thread radiates from — a fixed spot near the
// board's top-left corner, in the same unscaled coordinate space as
// note.position_x/y.
const ANCHOR_X = 36;
const ANCHOR_Y = 36;

interface FocusWallCanvasProps {
  initialNotes: FocusNote[];
  initialCategories: FocusCategory[];
}

export function FocusWallCanvas({ initialNotes, initialCategories }: FocusWallCanvasProps) {
  const [notes, setNotes] = useState(initialNotes);
  const [zoom, setZoom] = useState(1);
  // Categories are now an open set (built-ins + whatever the user has
  // created), so the URL filter is a plain string, not a fixed literal union.
  const [category, setCategory] = useQueryState("category", parseAsString.withDefault(NOTE_CATEGORY.ALL));
  const { categories, addCategory, removeCategory } = useFocusCategories(initialCategories);
  const wallRef = useRef<HTMLDivElement>(null);
  const { isFullscreen, toggle: toggleFullscreen } = useFullscreen(wallRef);

  async function handleRemoveCategory(target: FocusCategory) {
    if (category === target.name) setCategory(NOTE_CATEGORY.ALL);
    await removeCategory(target.id);
  }

  async function handleMoveNotes(from: string, to: string) {
    const ids = notes.filter((n) => n.category === from).map((n) => n.id);
    setNotes((prev) => prev.map((n) => (n.category === from ? { ...n, category: to } : n)));
    await Promise.all(ids.map((id) => updateNoteAction(id, { category: to })));
  }

  async function handleDeleteNotesInCategory(targetCategory: string) {
    const ids = notes.filter((n) => n.category === targetCategory).map((n) => n.id);
    setNotes((prev) => prev.filter((n) => n.category !== targetCategory));
    await Promise.all(ids.map((id) => deleteNoteAction(id)));
  }

  const visible = category === NOTE_CATEGORY.ALL ? notes : notes.filter((n) => n.category === category);
  const urgentVisible = visible.filter((n) => n.category === NOTE_CATEGORY.URGENT);

  // Sized off all notes (not just the filtered-visible ones) so switching
  // category filters never changes the canvas size or scroll position.
  const canvasWidth = Math.max(
    CANVAS_MIN_WIDTH,
    ...notes.map((n) => n.position_x + NOTE_WIDTH + CANVAS_MARGIN),
  );
  const canvasHeight = Math.max(
    CANVAS_MIN_HEIGHT,
    ...notes.map((n) => n.position_y + NOTE_MIN_HEIGHT + CANVAS_MARGIN),
  );

  function handleAdd() {
    const color = NOTE_COLOR_OPTIONS[Math.floor(Math.random() * NOTE_COLOR_OPTIONS.length)];
    const draft: FocusNote = {
      id: `draft-${crypto.randomUUID()}`,
      user_id: "",
      text: "",
      color,
      category: category === NOTE_CATEGORY.ALL ? NOTE_CATEGORY.PERSONAL : category,
      position_x: 40 + Math.random() * 200,
      position_y: 40 + Math.random() * 160,
      rotation: Math.random() * 4 - 2,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    setNotes((prev) => [...prev, draft]);
  }

  async function handleSaveDraft(draftId: string, text: string) {
    const draft = notes.find((n) => n.id === draftId);
    if (!draft) return;
    const result = await createNoteAction({
      text,
      color: draft.color,
      category: draft.category,
      position_x: draft.position_x,
      position_y: draft.position_y,
      rotation: draft.rotation,
    });
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Couldn't save the note.");
      setNotes((prev) => prev.filter((n) => n.id !== draftId));
      return;
    }
    const savedNote = result.data;
    setNotes((prev) => prev.map((n) => (n.id === draftId ? savedNote : n)));
  }

  async function handleMove(id: string, x: number, y: number) {
    // Keep the note's top-left non-negative — the canvas grows to fit
    // wherever it's dropped (see canvasWidth/canvasHeight above), so there's
    // no upper bound to clamp against.
    const clampedX = Math.max(x, 0);
    const clampedY = Math.max(y, 0);
    setNotes((prev) =>
      prev.map((n) => (n.id === id ? { ...n, position_x: clampedX, position_y: clampedY } : n)),
    );
    if (id.startsWith("draft-")) return;
    const result = await updateNoteAction(id, { position_x: clampedX, position_y: clampedY });
    if (!result.ok) toast.error(result.error ?? "Couldn't save the note's position.");
  }

  async function handleDelete(id: string) {
    setNotes((prev) => prev.filter((n) => n.id !== id));
    if (id.startsWith("draft-")) return;
    const result = await deleteNoteAction(id);
    if (!result.ok) toast.error(result.error ?? "Couldn't delete the note.");
  }

  function handleZoomIn() {
    setZoom((z) => Math.min(ZOOM_MAX, Math.round((z + ZOOM_STEP) * 100) / 100));
  }

  function handleZoomOut() {
    setZoom((z) => Math.max(ZOOM_MIN, Math.round((z - ZOOM_STEP) * 100) / 100));
  }

  return (
    <div className={cn(styles.wall, "relative h-full w-full")} ref={wallRef}>
      {/* Title — plain in the windowed view; becomes a stamped case-file
          wordmark once full screen (see .wordmark in the CSS module). Needs
          a fade backing in both states since the board sits edge-to-edge
          underneath it in the windowed view (see .headerBacking). */}
      <div
        className={cn(
          "pointer-events-none absolute inset-x-0 top-0 z-sticky flex items-start justify-between gap-4 p-4 sm:p-6",
          styles.headerBacking,
        )}
      >
        <div className="flex items-start gap-3">
          <Crosshair aria-hidden className={cn("mt-1 size-6 sm:mt-1.5", styles.wordmarkIcon)} />
          <div>
            <h1 className={cn("text-2xl font-bold tracking-tight sm:text-3xl", styles.wordmark)}>Focus Wall</h1>
            <p className={cn("text-xs", styles.caseLabel)}>
              {notes.length} note{notes.length === 1 ? "" : "s"} pinned
            </p>
          </div>
        </div>
      </div>

      {/* Category filter — a plain pill group in the windowed view; becomes
          folder tabs hanging off the board's top edge full screen. */}
      <div className="absolute inset-x-0 top-16 z-sticky flex justify-center px-4 sm:top-20">
        <CategoryTabs
          activeCategory={category}
          categories={categories}
          notes={notes}
          onAdd={addCategory}
          onDeleteNotesInCategory={handleDeleteNotesInCategory}
          onMoveNotes={handleMoveNotes}
          onRemoveCategory={handleRemoveCategory}
          onSelect={setCategory}
        />
      </div>

      {/* Frame + corkboard — edge-to-edge in the windowed view (.frame is
          inset:0 by default), gains a picture-frame margin + wood/cork
          texture full screen only (see .frame/.board in the CSS module). */}
      <div className={styles.frame}>
        <span aria-hidden className={cn(styles.screw, "left-2 top-2")} />
        <span aria-hidden className={cn(styles.screw, "right-2 top-2")} />
        <span aria-hidden className={cn(styles.screw, "bottom-2 left-2")} />
        <span aria-hidden className={cn(styles.screw, "bottom-2 right-2")} />

        {visible.length === 0 ? (
          <div className={cn(styles.board, "flex h-full w-full items-center justify-center p-8 text-center")}>
            <p className={cn("max-w-xs text-sm leading-relaxed", styles.emptyLabel)}>
              The wall is bare.
              <br />
              Tap + to pin your first thought.
            </p>
          </div>
        ) : (
          <div className={cn(styles.board, "h-full w-full overflow-auto")}>
            {/* Spacer sized to the zoomed canvas so the scroll container's
                scrollWidth/scrollHeight cover the scaled content — a bare
                `transform: scale` on the inner canvas alone doesn't grow the
                ancestor's scrollable area, leaving zoomed-in content unreachable. */}
            {/* eslint-disable-next-line no-restricted-syntax -- scroll spacer must track the live canvas size and zoom level */}
            <div style={{ width: canvasWidth * zoom, height: canvasHeight * zoom }}>
              <div
                className="relative"
                // eslint-disable-next-line no-restricted-syntax -- content-derived canvas size + user-driven zoom level, not expressible as static classes
                style={{ width: canvasWidth, height: canvasHeight, transform: `scale(${zoom})`, transformOrigin: "0 0" }}
              >
                {urgentVisible.length > 0 && (
                  <div className={styles.thread}>
                    {/* Red thread from the master pin to every urgent note,
                        full screen only — redrawn from live position_x/y on
                        every render, so it tracks a drag once dropped. It
                        doesn't follow the note mid-drag (that's an
                        imperative style mutation, not state) — acceptable
                        for a decorative flourish. */}
                    <svg
                      aria-hidden
                      className="pointer-events-none absolute inset-0 overflow-visible"
                      height={canvasHeight}
                      width={canvasWidth}
                    >
                      {urgentVisible.map((note) => {
                        const nx = note.position_x + NOTE_WIDTH / 2;
                        const ny = note.position_y;
                        const midX = (ANCHOR_X + nx) / 2;
                        const midY = (ANCHOR_Y + ny) / 2 + 26;
                        return (
                          <path
                            d={`M ${ANCHOR_X} ${ANCHOR_Y} Q ${midX} ${midY} ${nx} ${ny}`}
                            fill="none"
                            key={note.id}
                            stroke="var(--alert)"
                            strokeWidth={2}
                          />
                        );
                      })}
                    </svg>
                    <span
                      aria-hidden
                      className={cn(styles.pin, styles.pinUrgent, "size-4")}
                      // eslint-disable-next-line no-restricted-syntax -- fixed anchor in the canvas's own unscaled coordinate space; transform:none cancels .pin's note-relative centering transform, which doesn't apply to a standalone anchor
                      style={{ left: ANCHOR_X, top: ANCHOR_Y, transform: "none" }}
                    />
                  </div>
                )}
                {visible.map((note) => (
                  <StickyNote
                    key={note.id}
                    note={note}
                    zoom={zoom}
                    onDelete={handleDelete}
                    onMove={handleMove}
                    onSaveDraft={handleSaveDraft}
                  />
                ))}
              </div>
            </div>
          </div>
        )}
      </div>

      <div
        className={cn(
          styles.controlPlate,
          "fixed bottom-20 right-24 z-sticky flex items-center gap-1 rounded-full p-1 lg:bottom-8 lg:right-28",
        )}
      >
        <Button
          aria-label="Zoom out"
          className={cn("touch-target rounded-full", styles.controlBtn)}
          disabled={zoom <= ZOOM_MIN}
          size="icon"
          variant="ghost"
          onClick={handleZoomOut}
        >
          <ZoomOut aria-hidden className="size-4" />
        </Button>
        <span className={cn("w-10 text-center text-xs", styles.caseLabel)}>{Math.round(zoom * 100)}%</span>
        <Button
          aria-label="Zoom in"
          className={cn("touch-target rounded-full", styles.controlBtn)}
          disabled={zoom >= ZOOM_MAX}
          size="icon"
          variant="ghost"
          onClick={handleZoomIn}
        >
          <ZoomIn aria-hidden className="size-4" />
        </Button>
        <span aria-hidden className={cn("mx-0.5 h-5 w-px", styles.divider)} />
        <Button
          aria-label={isFullscreen ? "Exit full screen" : "Full screen"}
          className={cn("touch-target rounded-full", styles.controlBtn)}
          size="icon"
          variant="ghost"
          onClick={toggleFullscreen}
        >
          {isFullscreen ? (
            <Minimize2 aria-hidden className="size-4" />
          ) : (
            <Maximize2 aria-hidden className="size-4" />
          )}
        </Button>
      </div>

      <div className="fixed bottom-20 right-6 z-sticky lg:bottom-8 lg:right-8">
        <Button
          aria-label="Pin a new note"
          className={cn("size-14 rounded-full hover:bg-transparent", styles.addPin)}
          size="icon"
          variant="ghost"
          onClick={handleAdd}
        >
          <Plus aria-hidden className="size-6" />
        </Button>
      </div>
    </div>
  );
}
