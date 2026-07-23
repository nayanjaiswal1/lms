"use client";

import { useCallback, useRef, useState } from "react";
import { ResizablePanelGroup, ResizablePanel, ResizableHandle } from "@/components/ui/resizable";
import { SheetTable, type GroupBy } from "@/components/sheets/sheet-table";
import { sheetRowId } from "@/components/sheets/sheet-table-row";
import { SheetNotesPanel } from "@/components/sheets/sheet-notes-panel";
import { noteBlockId } from "@/components/sheets/sheet-note-block";
import { useNotesPanel } from "@/components/sheets/notes-panel-context";
import type { SheetItem } from "@/lib/server/sheets";

interface SheetSplitViewProps {
  sheetId: string;
  items: SheetItem[];
  isOwner: boolean;
  isEditMode: boolean;
  groupBy: GroupBy;
  isAdding: boolean;
  cancelAddItemHref: string;
}

// A fast scroll gesture crosses several short blocks in a row — each crossing
// re-fires onActiveChange, and without debouncing, every one of those kicks
// off its own smooth scrollIntoView on the left list, so several competing
// animations interrupt each other mid-flight and the list visibly stutters.
// Only the id the user's scroll settles on should actually trigger a follow.
const FOLLOW_DEBOUNCE_MS = 150;

// Clicking a left row kicks off its own smooth scrollIntoView on the right
// panel — and every block that scroll passes through on the way to its
// target crosses the notes feed's own "active" band, re-firing onActiveChange
// for whatever happens to be mid-transit. Left unguarded, that chases the
// left list right back off the row the user just clicked. Suppressing the
// right→left follow until the animation actually *arrives* at the clicked
// item breaks the loop — a fixed delay isn't enough, since a smooth-scroll to
// a far-down (e.g. "middle of a 149-item sheet") item covers a lot more
// distance, and takes correspondingly longer to settle, than one to a nearby
// item; a delay sized for the fast case reads the mid-flight block as
// "arrived" for the slow case and follows it instead.
const FOLLOW_SUPPRESS_MAX_MS = 3000;

export function SheetSplitView(props: SheetSplitViewProps) {
  const [activeItemId, setActiveItemId] = useState<string | null>(null);
  const { open: notesOpen, editing: notesEditing, openPanel } = useNotesPanel();
  const followTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  // Which item scrollToItem's own animation is still travelling toward — null
  // once it's confirmed arrived (or the safety-net timeout below gives up).
  const pendingTargetId = useRef<string | null>(null);
  const suppressFollowUntil = useRef(0);

  function scrollToItem(itemId: string) {
    setActiveItemId(itemId);
    openPanel();
    pendingTargetId.current = itemId;
    // Safety net only — in case the target block never reports itself as
    // arrived (e.g. it's removed mid-scroll), so this doesn't suppress
    // following forever.
    suppressFollowUntil.current = Date.now() + FOLLOW_SUPPRESS_MAX_MS;
    // The notes panel may have just been mounted by the state update above —
    // wait a frame so its DOM actually exists before looking up the block.
    // The left list also just remounted into the resizable-panel layout (a
    // different tree position than the plain, no-panel render), so it starts
    // back at scrollTop 0 — jump it (no animation, it's not visible yet as a
    // scroll) back to the row the user actually clicked.
    requestAnimationFrame(() => {
      document.getElementById(sheetRowId(itemId))?.scrollIntoView({ behavior: "auto", block: "center" });
      document.getElementById(noteBlockId(itemId))?.scrollIntoView({ behavior: "smooth", block: "start" });
    });
  }

  // The reverse direction: the notes feed reports which block scrolled into
  // view, and the matching left-list row follows it — "nearest" is a no-op
  // when the row set the active id itself (via scrollToItem, already
  // visible), and brings it back on screen when the right panel scrolled it
  // out of the left panel's own (independently scrolling) view.
  const followActiveItem = useCallback((itemId: string) => {
    if (pendingTargetId.current) {
      if (itemId === pendingTargetId.current) {
        pendingTargetId.current = null; // arrived — safe to follow again
      } else if (Date.now() < suppressFollowUntil.current) {
        return; // still mid-flight past some other block — ignore it
      } else {
        pendingTargetId.current = null; // safety net expired, resume anyway
      }
    }
    setActiveItemId(itemId);
    if (followTimer.current) clearTimeout(followTimer.current);
    followTimer.current = setTimeout(() => {
      document.getElementById(sheetRowId(itemId))?.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }, FOLLOW_DEBOUNCE_MS);
  }, []);

  return (
    // react-resizable-panels hardcodes overflow:auto + maxHeight:100% on each
    // panel — that only creates an actual (independently-scrolling) box when
    // an ancestor gives the group a real height, so this wrapper is required,
    // not decorative.
    <div className="h-[calc(100dvh-12rem)] min-h-[420px] overflow-y-auto">
      {notesOpen ? (
        <ResizablePanelGroup orientation="horizontal">
          <ResizablePanel defaultSize="32%" id="sheet-list" maxSize="55%" minSize="22%">
            <SheetTable {...props} activeItemId={activeItemId} onSelectItem={scrollToItem} />
          </ResizablePanel>
          <ResizableHandle withHandle orientation="horizontal" />
          <ResizablePanel defaultSize="68%" id="sheet-notes" minSize="30%">
            <div className="min-h-0 h-full flex-1 overflow-y-auto pl-4 pt-3">
              <SheetNotesPanel
                activeItemId={activeItemId}
                isEditing={notesEditing}
                items={props.items}
                onActiveChange={followActiveItem}
              />
            </div>
          </ResizablePanel>
        </ResizablePanelGroup>
      ) : (
        <SheetTable {...props} activeItemId={activeItemId} onSelectItem={scrollToItem} />
      )}
    </div>
  );
}
