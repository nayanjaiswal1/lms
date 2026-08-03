"use client";

import { useRef, useState } from "react";
import { Maximize2, Minimize2, Plus, StickyNote as StickyNoteIcon, ZoomIn, ZoomOut } from "lucide-react";
import { parseAsStringLiteral, useQueryState } from "nuqs";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { StickyNote } from "@/components/focus-wall/sticky-note";
import { useFullscreen } from "@/components/focus-wall/use-fullscreen";
import { createNoteAction, deleteNoteAction, updateNoteAction } from "@/app/(app)/focus-wall/actions";
import type { FocusNote } from "@/lib/server/focus-wall";
import { NOTE_CATEGORY, NOTE_CATEGORY_FILTER_OPTIONS, NOTE_COLOR_OPTIONS } from "@/lib/constants";

const CATEGORY_FILTERS = NOTE_CATEGORY_FILTER_OPTIONS.map((o) => o.value);

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

interface FocusWallCanvasProps {
  initialNotes: FocusNote[];
}

export function FocusWallCanvas({ initialNotes }: FocusWallCanvasProps) {
  const [notes, setNotes] = useState(initialNotes);
  const [zoom, setZoom] = useState(1);
  const [category, setCategory] = useQueryState(
    "category",
    parseAsStringLiteral(CATEGORY_FILTERS).withDefault(NOTE_CATEGORY.ALL),
  );
  const wallRef = useRef<HTMLDivElement>(null);
  const { isFullscreen, toggle: toggleFullscreen } = useFullscreen(wallRef);

  const visible = category === NOTE_CATEGORY.ALL ? notes : notes.filter((n) => n.category === category);

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
    <div className="relative h-full w-full bg-background" ref={wallRef}>
      {/* Scrollable canvas fills the whole wrapper edge-to-edge — the floating
          title/filter bar and the fixed zoom/fullscreen/add controls all sit
          on top of it (z-sticky), not in normal document flow, so the wall
          itself gets the full height instead of being pushed down. */}
      <div className="absolute inset-0 overflow-auto">
        {visible.length === 0 ? (
          <div className="empty-state h-full py-16">
            <p className="text-center text-muted-foreground">
              No notes here yet.
              <br />
              Tap the + button to stick one up.
            </p>
          </div>
        ) : (
          // Spacer sized to the zoomed canvas so the scroll container's
          // scrollWidth/scrollHeight cover the scaled content — a bare
          // `transform: scale` on the inner canvas alone doesn't grow the
          // ancestor's scrollable area, leaving zoomed-in content unreachable.
          // eslint-disable-next-line no-restricted-syntax -- scroll spacer must track the live canvas size and zoom level
          <div style={{ width: canvasWidth * zoom, height: canvasHeight * zoom }}>
            <div
              className="relative"
              // eslint-disable-next-line no-restricted-syntax -- content-derived canvas size + user-driven zoom level, not expressible as static classes
              style={{ width: canvasWidth, height: canvasHeight, transform: `scale(${zoom})`, transformOrigin: "0 0" }}
            >
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
        )}
      </div>

      {/* Floating title + note count */}
      <div className="pointer-events-none absolute inset-x-0 top-0 z-sticky flex items-center justify-between gap-4 bg-gradient-to-b from-background via-background/80 to-transparent p-4">
        <div className="flex items-center gap-3">
          <StickyNoteIcon aria-hidden className="size-6 text-primary" />
          <h1 className="page-title">Focus Wall</h1>
        </div>
        <span className="text-sm text-muted-foreground">
          {notes.length} note{notes.length === 1 ? "" : "s"}
        </span>
      </div>

      {/* Floating category filter */}
      <div className="absolute inset-x-0 top-16 z-sticky flex justify-center px-4">
        <div className="flex flex-wrap justify-center gap-1 rounded-full border border-border bg-card/90 p-1 shadow-card backdrop-blur">
          {NOTE_CATEGORY_FILTER_OPTIONS.map((opt) => (
            <Button
              className="rounded-full"
              key={opt.value}
              size="sm"
              variant={category === opt.value ? "default" : "ghost"}
              onClick={() => setCategory(opt.value)}
            >
              {opt.label}
            </Button>
          ))}
        </div>
      </div>

      <div className="fixed bottom-20 right-24 z-sticky flex items-center gap-1 rounded-full border border-border bg-card p-1 shadow-card lg:bottom-8 lg:right-28">
        <Button
          aria-label="Zoom out"
          className="touch-target rounded-full"
          disabled={zoom <= ZOOM_MIN}
          size="icon"
          variant="ghost"
          onClick={handleZoomOut}
        >
          <ZoomOut aria-hidden className="size-4" />
        </Button>
        <span className="w-10 text-center text-xs text-muted-foreground">{Math.round(zoom * 100)}%</span>
        <Button
          aria-label="Zoom in"
          className="touch-target rounded-full"
          disabled={zoom >= ZOOM_MAX}
          size="icon"
          variant="ghost"
          onClick={handleZoomIn}
        >
          <ZoomIn aria-hidden className="size-4" />
        </Button>
        <span aria-hidden className="mx-0.5 h-5 w-px bg-border" />
        <Button
          aria-label={isFullscreen ? "Exit full screen" : "Full screen"}
          className="touch-target rounded-full"
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
        <Button aria-label="Add sticky note" className="size-14 rounded-full shadow-float" size="icon" onClick={handleAdd}>
          <Plus aria-hidden className="size-6" />
        </Button>
      </div>
    </div>
  );
}
