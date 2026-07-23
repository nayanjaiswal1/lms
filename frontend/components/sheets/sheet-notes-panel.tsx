"use client";

import { useCallback, useRef, useState } from "react";
import { SheetNoteBlock, noteBlockId } from "@/components/sheets/sheet-note-block";
import type { SheetItem } from "@/lib/server/sheets";

interface SheetNotesPanelProps {
  items: SheetItem[];
  activeItemId: string | null;
  onActiveChange: (id: string) => void;
  isEditing: boolean;
}

function idFromElement(target: Element): string {
  return target.id.slice("sheet-note-".length);
}

// The notes feed lives inside react-resizable-panels, which scrolls via its
// own bounded box rather than the page — rootMargin percentages only make
// sense measured against that box, not the full viewport, so the observers
// below need it as an explicit `root`.
function findScrollParent(el: HTMLElement): HTMLElement | null {
  let parent = el.parentElement;
  while (parent) {
    const overflowY = getComputedStyle(parent).overflowY;
    if (overflowY === "auto" || overflowY === "scroll") return parent;
    parent = parent.parentElement;
  }
  return null;
}

export function SheetNotesPanel({ items, activeItemId, onActiveChange, isEditing }: SheetNotesPanelProps) {
  const [mountedIds, setMountedIds] = useState<ReadonlySet<string>>(() => new Set());
  // top position (px from viewport top) of every block currently inside the
  // "active" band, keyed by item id — lets the observer pick the topmost
  // intersecting block deterministically instead of whichever one happened
  // to appear last in a single callback batch (which produced a stuck
  // highlight when several blocks crossed the band in one scroll tick).
  const activeTops = useRef(new Map<string, number>());

  // Two observers set up in a ref callback (React 19 cleanup) rather than
  // useEffect, same pattern as module-toc.tsx: their lifetime is exactly this
  // list's mount/unmount. Wrapped in useCallback so the ref identity only
  // changes when `items` does — without it, every scroll-driven state update
  // (activeItemId, mountedIds) redefines this function, and React tears down
  // + rebuilds both observers (re-querying every item by id) on every single
  // highlight change, which is what was freezing the tab while scrolling.
  //  - activeObserver: narrow band near the top of the viewport, drives which
  //    left-list row is highlighted as the user scrolls (like module-toc).
  //  - mountObserver: wide band around the viewport, lazily mounts the real
  //    TipTap editor only for blocks near what's visible — a system sheet can
  //    have 400+ problems, and mounting that many editors at once would hang
  //    the tab. mountedIds only grows, so a scrolled-past block stays mounted
  //    instead of flickering back to its skeleton.
  const observeBlocks = useCallback(
    (node: HTMLElement | null) => {
      if (!node) return;
      const blocks = items
        .map((item) => document.getElementById(noteBlockId(item.id)))
        .filter((el): el is HTMLElement => el !== null);
      if (blocks.length === 0) return;

      const root = findScrollParent(node);

      activeTops.current.clear();
      const activeObserver = new IntersectionObserver(
        (observed) => {
          for (const entry of observed) {
            const id = idFromElement(entry.target);
            if (entry.isIntersecting) activeTops.current.set(id, entry.boundingClientRect.top);
            else activeTops.current.delete(id);
          }
          let bestId: string | null = null;
          let bestTop = Infinity;
          for (const [id, top] of activeTops.current) {
            if (top < bestTop) {
              bestTop = top;
              bestId = id;
            }
          }
          if (bestId) onActiveChange(bestId);
        },
        { root, rootMargin: "-16px 0px -70% 0px" },
      );

      const mountObserver = new IntersectionObserver(
        (observed) => {
          const newlyVisible = observed.filter((entry) => entry.isIntersecting);
          if (newlyVisible.length === 0) return;
          setMountedIds((prev) => {
            const next = new Set(prev);
            for (const entry of newlyVisible) next.add(idFromElement(entry.target));
            return next;
          });
        },
        { root, rootMargin: "400px 0px 400px 0px" },
      );

      for (const el of blocks) {
        activeObserver.observe(el);
        mountObserver.observe(el);
      }
      return () => {
        activeObserver.disconnect();
        mountObserver.disconnect();
      };
    },
    [items, onActiveChange],
  );

  return (
    <div
      className="divide-y divide-border rounded-lg border border-border bg-card shadow-card"
      ref={observeBlocks}
    >
      {items.map((item) => (
        <SheetNoteBlock
          editable={isEditing}
          isActive={item.id === activeItemId}
          isMounted={mountedIds.has(item.id)}
          item={item}
          key={item.id}
        />
      ))}
    </div>
  );
}
