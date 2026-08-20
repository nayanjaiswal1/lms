"use client";

import { useEffect } from "react";
import { Sparkles } from "lucide-react";

import { LessonFloatingPanel } from "@/components/shared/lesson-floating-panel";
import { JournalEntryForm } from "@/components/journal/journal-entry-form";
import { MIN_STRUCTURE_LENGTH, useJournalStructure } from "@/components/journal/use-journal-structure";
import type { JournalCategoryNode } from "@/lib/server/journal";

interface JournalPasteCaptureProps {
  categories: JournalCategoryNode[];
}

function isEditableTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  return target.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName);
}

// Paste anywhere on the journal page outside a real input/textarea and AI
// suggests a category/subcategory/title, plus a cleaned-up rewrite of the
// text itself (structure, grammar, conciseness — same facts, no invented
// ones). Opens as the same bottom-right floating panel "Ask your AI"/ticket
// chat use (LessonFloatingPanel), not a modal — nothing saves until the
// user reviews the prefilled form (still fully editable) and hits Save.
export function JournalPasteCapture({ categories }: JournalPasteCaptureProps) {
  const { open, draft, error, isPending, structure, close } = useJournalStructure();

  // Global paste listener — there's no non-effect equivalent for a
  // document-level browser event (same reasoning as LabQuickOpen's global
  // Ctrl+P listener).
  useEffect(() => {
    function onPaste(e: ClipboardEvent) {
      if (isEditableTarget(e.target)) return;
      const text = e.clipboardData?.getData("text/plain")?.trim();
      if (!text || text.length < MIN_STRUCTURE_LENGTH) return;
      e.preventDefault();
      structure(text);
    }
    document.addEventListener("paste", onPaste);
    return () => document.removeEventListener("paste", onPaste);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- structure is stable for the listener's lifetime, re-subscribing on every render isn't needed
  }, []);

  if (!open) return null;

  return (
    <LessonFloatingPanel
      ariaLabel="New journal entry from paste"
      icon={<Sparkles aria-hidden className="size-4 text-ai" />}
      title="New entry from paste"
      onClose={close}
    >
      <div className="min-h-0 flex-1 overflow-y-auto px-4 py-3">
        {isPending ? (
          <div className="flex items-center gap-2 py-8 text-sm text-muted-foreground">
            <span className="ai-badge">AI</span> Structuring your paste…
          </div>
        ) : error ? (
          <p className="py-4 text-sm text-destructive">{error}</p>
        ) : draft ? (
          <JournalEntryForm categories={categories} draft={draft} onSaved={close} />
        ) : null}
      </div>
    </LessonFloatingPanel>
  );
}
