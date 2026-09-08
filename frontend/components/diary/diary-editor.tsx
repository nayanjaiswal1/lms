"use client";

import { History, NotebookPen, SpellCheck, Sparkles } from "lucide-react";
import { useEffect, useRef, useState, useTransition, type ReactNode } from "react";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import { applyAnalysisAction, saveDiaryEntryAction } from "@/app/(app)/diary/actions";
import { HIGHLIGHT_KIND_LABEL } from "@/lib/diary/highlight-labels";
import type { DiaryHighlight } from "@/lib/server/diary";
import {
  DiaryAnalyzeReviewPanel,
  resolveAnalyzeHighlights,
  useAnalyzeReview,
} from "@/components/diary/diary-analyze-review";
import {
  DiaryFixEnglishReviewPanel,
  resolveFixEnglishText,
  useFixEnglishReview,
} from "@/components/diary/diary-fix-english-review";

const SAVE_DEBOUNCE_MS = 1500;

const draftKey = (date: string) => `diary-draft-${date}`;

function writeDraft(date: string, value: string) {
  try {
    localStorage.setItem(draftKey(date), value);
  } catch {
    // Storage unavailable (private mode, quota) — the debounced server save
    // still covers persistence, this is just a local safety net.
  }
}

function clearDraft(date: string) {
  try {
    localStorage.removeItem(draftKey(date));
  } catch {
    // Nothing to clean up if storage was never written.
  }
}

// Renders content with highlight spans wrapped in <mark>. Highlights are
// sorted and clipped defensively — the AI-produced offsets are trusted for
// happy-path text but a stale/overlapping span must never crash the editor.
function renderHighlighted(content: string, highlights: DiaryHighlight[]): ReactNode[] {
  const sorted = [...highlights].sort((a, b) => a.start - b.start);
  const nodes: ReactNode[] = [];
  let cursor = 0;
  for (const h of sorted) {
    const start = Math.max(h.start, cursor);
    const end = Math.min(h.end, content.length);
    if (start >= end) continue;
    if (start > cursor) nodes.push(content.slice(cursor, start));
    nodes.push(
      <mark className="diary-highlight" key={`${start}-${end}`} title={HIGHLIGHT_KIND_LABEL[h.kind]}>
        {content.slice(start, end)}
      </mark>,
    );
    cursor = end;
  }
  if (cursor < content.length) nodes.push(content.slice(cursor));
  return nodes;
}

function formatEntryHeadline(date: string): string {
  return new Date(`${date}T00:00:00`).toLocaleDateString(undefined, {
    weekday: "long",
    month: "short",
    day: "numeric",
  });
}

interface DiaryEditorProps {
  date: string;
  initialContent: string;
  highlights: DiaryHighlight[];
  historyContent: ReactNode;
}

export function DiaryEditor({ date, initialContent, highlights, historyContent }: DiaryEditorProps) {
  const [content, setContent] = useState(initialContent);
  const [showHistory, setShowHistory] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [isApplying, startApplying] = useTransition();
  const [isReviewing, startReviewing] = useTransition();
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const mirrorRef = useRef<HTMLDivElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const analyzeReview = useAnalyzeReview();
  const fixEnglishReview = useFixEnglishReview();

  // Crash-recovery draft only, not cross-device sync — server PATCH stays
  // the source of truth. Must be read after mount, not during render, so
  // SSR and the first client render match (no hydration mismatch on the
  // highlight mirror below) — same reasoning as Sidebar's collapsed state.
  useEffect(() => {
    try {
      const draft = localStorage.getItem(draftKey(date));
      if (draft !== null && draft !== initialContent) setContent(draft);
    } catch {
      // Storage unavailable — nothing to restore.
    }
    // Only ever run once per mounted date; initialContent is this effect's
    // baseline, not a dependency to react to.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [date]);

  function scheduleSave(value: string) {
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => {
      startTransition(async () => {
        const result = await saveDiaryEntryAction(date, value);
        if (result.ok) clearDraft(date);
      });
    }, SAVE_DEBOUNCE_MS);
  }

  function handleChange(value: string) {
    setContent(value);
    writeDraft(date, value);
    scheduleSave(value);
  }

  function saveContent(next: string) {
    setContent(next);
    writeDraft(date, next);
    if (saveTimer.current) clearTimeout(saveTimer.current);
    startTransition(async () => {
      const result = await saveDiaryEntryAction(date, next);
      if (result.ok) clearDraft(date);
    });
  }

  // "Fix English": a standalone grammar/spelling diff — shows the AI's
  // proposed corrections span-by-span (nothing saved yet) and only writes
  // the resolved text once the writer confirms which spans to keep.
  function handleFixEnglish() {
    startReviewing(async () => {
      await fixEnglishReview.open(date, content);
    });
  }

  function handleFixEnglishConfirm() {
    const resolved = resolveFixEnglishText(fixEnglishReview.state.segments, fixEnglishReview.state.decisions);
    saveContent(resolved);
    fixEnglishReview.close();
  }

  // "AI": the separate habit/task/goal detection pass, over whatever text is
  // currently on the page (independent of Fix English — run either, both,
  // or neither, in any order).
  function handleAIReview() {
    startReviewing(async () => {
      await analyzeReview.open(date, content);
    });
  }

  function handleAnalyzeApply() {
    const editedHighlights = resolveAnalyzeHighlights(analyzeReview.state.items);
    // Flush the pending debounced save first and save synchronously — Apply
    // reads the entry's saved content for its hash bookkeeping, and the
    // detected spans' offsets must still match what's on the server.
    if (saveTimer.current) clearTimeout(saveTimer.current);
    startApplying(async () => {
      const saveResult = await saveDiaryEntryAction(date, content);
      if (saveResult.ok) clearDraft(date);
      await applyAnalysisAction(date, editedHighlights);
      analyzeReview.close();
    });
  }

  function syncMirrorScroll() {
    if (mirrorRef.current && textareaRef.current) {
      mirrorRef.current.scrollTop = textareaRef.current.scrollTop;
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-border pb-2">
        <h2 className="diary-paper-headline text-2xl font-bold text-foreground sm:text-3xl">
          {showHistory ? "History" : formatEntryHeadline(date)}
        </h2>
        <div className="flex items-center gap-3">
          {!showHistory && (
            <span
              className={cn(
                "text-xs text-muted-foreground",
                !isPending && !isApplying && !isReviewing && "invisible",
              )}
            >
              {isReviewing ? "Reviewing…" : isApplying ? "Applying…" : "Saving…"}
            </span>
          )}
          <Button
            aria-label={showHistory ? "Back to today" : "Show history"}
            aria-pressed={showHistory}
            className={cn("touch-target", showHistory && "bg-accent")}
            size="icon"
            type="button"
            variant="outline"
            onClick={() => setShowHistory((v) => !v)}
          >
            {showHistory ? (
              <NotebookPen aria-hidden className="size-4" />
            ) : (
              <History aria-hidden className="size-4" />
            )}
          </Button>
          {!showHistory && (
            <>
              <Button
                className="gap-2"
                disabled={
                  analyzeReview.state.status !== "closed" ||
                  fixEnglishReview.state.status !== "closed" ||
                  isReviewing ||
                  content.trim() === ""
                }
                type="button"
                variant="outline"
                onClick={handleFixEnglish}
              >
                <SpellCheck aria-hidden className="size-4" />
                Fix English
              </Button>
              <Button
                className="gap-2"
                disabled={
                  analyzeReview.state.status !== "closed" ||
                  fixEnglishReview.state.status !== "closed" ||
                  isReviewing ||
                  content.trim() === ""
                }
                type="button"
                variant="outline"
                onClick={handleAIReview}
              >
                <Sparkles aria-hidden className="size-4" />
                AI
              </Button>
            </>
          )}
        </div>
      </div>

      {showHistory ? (
        historyContent
      ) : fixEnglishReview.state.status !== "closed" ? (
        <DiaryFixEnglishReviewPanel
          state={fixEnglishReview.state}
          onCancel={fixEnglishReview.close}
          onConfirm={handleFixEnglishConfirm}
          onSetAll={fixEnglishReview.setAll}
          onToggle={fixEnglishReview.toggle}
        />
      ) : analyzeReview.state.status !== "closed" ? (
        <DiaryAnalyzeReviewPanel
          state={analyzeReview.state}
          onCancel={analyzeReview.close}
          onConfirm={handleAnalyzeApply}
          onEditMetadata={analyzeReview.editMetadata}
          onEditText={analyzeReview.editText}
          onToggle={analyzeReview.toggle}
        />
      ) : (
        <div className="diary-lined relative min-h-[400px]">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 overflow-hidden whitespace-pre-wrap break-words text-base leading-8 text-foreground"
            ref={mirrorRef}
          >
            {renderHighlighted(content, highlights)}
            {/* trailing newline padding so the last line's mirror height matches the textarea */}
            {content.endsWith("\n") ? " " : null}
          </div>
          <Textarea
            className="diary-write-area relative h-full min-h-[400px] resize-none border-none bg-transparent p-0 text-base leading-8 text-transparent caret-foreground shadow-none focus-visible:ring-0"
            placeholder="Write today's entry…"
            ref={textareaRef}
            value={content}
            onChange={(e) => handleChange(e.target.value)}
            onScroll={syncMirrorScroll}
          />
        </div>
      )}
    </div>
  );
}
