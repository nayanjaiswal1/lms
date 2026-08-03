"use client";

import { useRef, useState } from "react";
import { AlertTriangle, FlaskConical, Heart, Tag, X, type LucideIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import type { FocusNote } from "@/lib/server/focus-wall";
import { cn } from "@/lib/utils";
import styles from "./focus-wall.module.css";

interface StickyNoteProps {
  note: FocusNote;
  zoom: number;
  onMove: (id: string, x: number, y: number) => void;
  onDelete: (id: string) => void;
  onSaveDraft: (draftId: string, text: string) => void;
}

const LEAVE_DURATION_MS = 350;

// Decorative background icon per category — matches the mockup's science-flask
// mark on study notes. Faint and pointer-events-none, purely tactile flourish.
// Custom (user-created) categories fall back to a generic tag icon below.
const CATEGORY_ICON: Record<string, LucideIcon> = {
  study: FlaskConical,
  personal: Heart,
  urgent: AlertTriangle,
};

const ICON_CORNER_CLASS = ["bottom-3 right-3", "bottom-3 left-3", "top-9 right-3", "top-9 left-3"];

// Card "material" per note color — kept as static literal classes (not
// string-templated) so Tailwind/CSS-modules can see them at build time.
const CARD_CLASS: Record<string, string> = {
  yellow: styles.cardYellow,
  blue: styles.cardBlue,
  pink: styles.cardPink,
  green: styles.cardGreen,
};

// Deterministic per-note "randomness" (stable across re-renders) for the
// background icon's corner + tilt, derived from the note's own id.
function hashCode(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return Math.abs(h);
}

export function StickyNote({ note, zoom, onMove, onDelete, onSaveDraft }: StickyNoteProps) {
  const [isLeaving, setIsLeaving] = useState(false);
  const elRef = useRef<HTMLDivElement>(null);
  const dragRef = useRef<{ startClientX: number; startClientY: number; startX: number; startY: number } | null>(null);

  const isDraft = note.id.startsWith("draft-");
  const isUrgent = note.category === "urgent";
  const hash = hashCode(note.id);
  const CategoryIcon = CATEGORY_ICON[note.category] ?? Tag;
  const iconCornerClass = ICON_CORNER_CLASS[hash % ICON_CORNER_CLASS.length];
  const iconRotation = (hash % 40) - 20;

  function handlePointerDown(e: React.PointerEvent<HTMLDivElement>) {
    if ((e.target as HTMLElement).closest("button, textarea")) return;
    dragRef.current = {
      startClientX: e.clientX,
      startClientY: e.clientY,
      startX: note.position_x,
      startY: note.position_y,
    };
    e.currentTarget.setPointerCapture(e.pointerId);
  }

  function handlePointerMove(e: React.PointerEvent<HTMLDivElement>) {
    const drag = dragRef.current;
    if (!drag || !elRef.current) return;
    // Divide by zoom: the note sits inside a scaled wrapper, so a screen-pixel
    // pointer delta maps to a larger/smaller delta in the note's own (unscaled)
    // position_x/position_y coordinate space.
    elRef.current.style.left = `${drag.startX + (e.clientX - drag.startClientX) / zoom}px`;
    elRef.current.style.top = `${drag.startY + (e.clientY - drag.startClientY) / zoom}px`;
  }

  function handlePointerUp(e: React.PointerEvent<HTMLDivElement>) {
    const drag = dragRef.current;
    if (!drag || !elRef.current) return;
    dragRef.current = null;
    e.currentTarget.releasePointerCapture(e.pointerId);
    onMove(note.id, parseFloat(elRef.current.style.left), parseFloat(elRef.current.style.top));
  }

  function handleDelete() {
    setIsLeaving(true);
    setTimeout(() => onDelete(note.id), LEAVE_DURATION_MS);
  }

  function handleDraftBlur(e: React.FocusEvent<HTMLTextAreaElement>) {
    const text = e.target.value.trim();
    if (text) {
      onSaveDraft(note.id, text);
    } else {
      onDelete(note.id);
    }
  }

  return (
    <div
      aria-label={`Sticky note${note.text ? `: ${note.text.slice(0, 40)}` : ", empty, being written"}`}
      className={cn(
        "absolute w-64 min-h-40 touch-none select-none rounded-sm p-5 pt-6 transition-opacity duration-slow ease-in-out cursor-grab active:cursor-grabbing",
        styles.card,
        CARD_CLASS[note.color],
        isLeaving && "opacity-0 pointer-events-none",
      )}
      ref={elRef}
      role="note"
      // eslint-disable-next-line no-restricted-syntax -- position/rotation are per-note freeform placement data, not expressible as static classes
      style={{
        left: note.position_x,
        top: note.position_y,
        transform: isLeaving ? "translateY(100px) rotate(15deg) scale(0.95)" : `rotate(${note.rotation}deg)`,
      }}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
    >
      <span aria-hidden className={cn(styles.pin, isUrgent && styles.pinUrgent)} />
      <span aria-hidden className={styles.tornEdge} />

      <Button
        aria-label="Remove note"
        className={cn("touch-target absolute right-1 top-1 z-raised", styles.deleteBtn)}
        size="icon"
        variant="ghost"
        onClick={handleDelete}
      >
        <X aria-hidden className="size-4" />
      </Button>

      <CategoryIcon
        aria-hidden
        className={cn("absolute size-10 pointer-events-none", styles.categoryIcon, iconCornerClass)}
        // eslint-disable-next-line no-restricted-syntax -- per-note deterministic tilt, not expressible as a static class
        style={{ transform: `rotate(${iconRotation}deg)` }}
      />

      <span className={cn("mb-2 block text-xs font-bold uppercase", styles.categoryLabel)}>{note.category}</span>

      {isDraft ? (
        <Textarea
          autoFocus
          className={cn(
            "relative h-40 resize-none border-none bg-transparent p-0 font-handwritten text-xl leading-relaxed shadow-none",
            styles.draftInput,
          )}
          defaultValue=""
          placeholder="Write something…"
          onBlur={handleDraftBlur}
        />
      ) : (
        <p className={cn("relative whitespace-pre-wrap font-handwritten text-xl leading-relaxed", styles.noteText)}>
          {note.text}
        </p>
      )}
    </div>
  );
}
