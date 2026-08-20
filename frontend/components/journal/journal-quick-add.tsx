"use client";

import { useRef } from "react";
import { Sparkles } from "lucide-react";

import { LessonFloatingPanel } from "@/components/shared/lesson-floating-panel";
import { JournalEntryForm } from "@/components/journal/journal-entry-form";
import { MIN_STRUCTURE_LENGTH, useJournalStructure } from "@/components/journal/use-journal-structure";
import type { JournalCategoryNode } from "@/lib/server/journal";

interface JournalQuickAddProps {
  categories: JournalCategoryNode[];
}

// Borderless, in-place "Add Learning" entry point — no dialog, no page nav.
// Write what you learned, then blur (click/tab away): if it's long enough to
// be worth an AI call, the same structuring flow paste-capture uses
// (useJournalStructure) opens with a category/subcategory/title suggestion,
// still fully editable in the form before anything saves.
export function JournalQuickAdd({ categories }: JournalQuickAddProps) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const { open, draft, error, isPending, structure, close } = useJournalStructure();

  function onBlur() {
    const el = textareaRef.current;
    if (!el) return;
    const text = el.value.trim();
    if (text.length < MIN_STRUCTURE_LENGTH) return;
    structure(text);
    el.value = "";
    el.style.height = "auto";
  }

  function autoGrow() {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${el.scrollHeight}px`;
  }

  return (
    <>
      <div className="rounded-lg bg-muted/40 px-3 py-1">
        <textarea
          ref={textareaRef}
          aria-label="Add what you learned today"
          className="w-full resize-none border-0 bg-transparent py-2 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus-visible:outline-none"
          placeholder="Write what you learned today…"
          rows={1}
          onBlur={onBlur}
          onInput={autoGrow}
        />
      </div>

      {open && (
        <LessonFloatingPanel
          ariaLabel="New journal entry"
          icon={<Sparkles aria-hidden className="size-4 text-ai" />}
          title="New entry"
          onClose={close}
        >
          <div className="min-h-0 flex-1 overflow-y-auto px-4 py-3">
            {isPending ? (
              <div className="flex items-center gap-2 py-8 text-sm text-muted-foreground">
                <span className="ai-badge">AI</span> Structuring what you wrote…
              </div>
            ) : error ? (
              <p className="py-4 text-sm text-destructive">{error}</p>
            ) : draft ? (
              <JournalEntryForm categories={categories} draft={draft} onSaved={close} />
            ) : null}
          </div>
        </LessonFloatingPanel>
      )}
    </>
  );
}
