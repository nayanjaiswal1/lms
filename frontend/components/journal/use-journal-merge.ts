"use client";

import { useEffect, useState, useTransition } from "react";
import { toast } from "sonner";

import { mergeJournalEntriesAction, undoJournalMergeAction } from "@/app/(app)/journal/actions";
import type { JournalEntry } from "@/lib/server/journal";

interface PendingUndo {
  keepId: string;
  keepContentBeforeMerge: string;
  removed: JournalEntry;
}

function isEditableTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  return target.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName);
}

// Drives JournalTimeline's "merge two cards for a day" flow: pick a day,
// select exactly two of its real (source: "journal") entries, confirm —
// their content combines destructively into one entry and the other is
// deleted (backend transaction, see MergeEntries). A single-slot Ctrl+Z
// undoes only the most recent merge — not a general undo/redo stack.
export function useJournalMerge(entries: JournalEntry[]) {
  const [mergeDay, setMergeDay] = useState<string | null>(null);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [pendingUndo, setPendingUndo] = useState<PendingUndo | null>(null);
  const [isPending, startTransition] = useTransition();

  function toggleMergeDay(date: string) {
    setMergeDay((current) => (current === date ? null : date));
    setSelectedIds([]);
  }

  function cancel() {
    setMergeDay(null);
    setSelectedIds([]);
  }

  function toggleSelect(id: string) {
    setSelectedIds((current) => {
      if (current.includes(id)) return current.filter((x) => x !== id);
      if (current.length >= 2) return current;
      return [...current, id];
    });
  }

  function confirmMerge() {
    const [keepId, otherId] = selectedIds;
    if (!keepId || !otherId) return;
    const keepEntry = entries.find((e) => e.id === keepId);
    if (!keepEntry) return;

    startTransition(async () => {
      const result = await mergeJournalEntriesAction(keepId, otherId);
      if (!result.ok || !result.data) {
        toast.error(result.error ?? "Couldn't merge these entries.");
        return;
      }
      setPendingUndo({ keepId, keepContentBeforeMerge: keepEntry.content, removed: result.data.removed });
      toast.success("Entries merged. Press Ctrl+Z to undo.");
      cancel();
    });
  }

  // Global keydown — there's no non-effect equivalent for a document-level
  // browser shortcut (same reasoning as the paste listener in
  // journal-paste-capture.tsx).
  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if (!(e.ctrlKey || e.metaKey) || e.key.toLowerCase() !== "z") return;
      if (isEditableTarget(e.target) || !pendingUndo) return;
      e.preventDefault();
      const snapshot = pendingUndo;
      setPendingUndo(null);
      startTransition(async () => {
        const result = await undoJournalMergeAction(snapshot.keepId, snapshot.keepContentBeforeMerge, snapshot.removed);
        if (!result.ok) {
          toast.error(result.error ?? "Couldn't undo the merge.");
          setPendingUndo(snapshot);
          return;
        }
        toast.success("Merge undone.");
      });
    }
    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  }, [pendingUndo]);

  return { mergeDay, selectedIds, isPending, toggleMergeDay, toggleSelect, confirmMerge, cancel };
}
