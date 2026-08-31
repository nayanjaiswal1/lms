"use client";

import { useRef, useState, useTransition, type ReactNode } from "react";

import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import { saveDiaryEntryAction } from "@/app/(app)/diary/actions";
import type { DiaryHighlight } from "@/lib/server/diary";
import { DiaryFixEnglishDialog } from "@/components/diary/diary-fix-english-dialog";

const SAVE_DEBOUNCE_MS = 1500;

const HIGHLIGHT_LABEL: Record<DiaryHighlight["kind"], string> = {
  habit: "Detected habit",
  task_done: "Task marked done",
  task_new: "New task captured",
  buy_new: "Added to buy list",
};

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
      <mark className="diary-highlight" key={`${start}-${end}`} title={HIGHLIGHT_LABEL[h.kind]}>
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
}

export function DiaryEditor({ date, initialContent, highlights }: DiaryEditorProps) {
  const [content, setContent] = useState(initialContent);
  const [isPending, startTransition] = useTransition();
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const mirrorRef = useRef<HTMLDivElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  function scheduleSave(value: string) {
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => {
      startTransition(async () => {
        await saveDiaryEntryAction(date, value);
      });
    }, SAVE_DEBOUNCE_MS);
  }

  function handleChange(value: string) {
    setContent(value);
    scheduleSave(value);
  }

  function handleFixEnglishApply(next: string) {
    setContent(next);
    if (saveTimer.current) clearTimeout(saveTimer.current);
    startTransition(async () => {
      await saveDiaryEntryAction(date, next);
    });
  }

  function syncMirrorScroll() {
    if (mirrorRef.current && textareaRef.current) {
      mirrorRef.current.scrollTop = textareaRef.current.scrollTop;
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-end justify-between gap-4 border-b border-border pb-2">
        <h2 className="diary-paper-headline text-2xl font-bold text-foreground sm:text-3xl">
          {formatEntryHeadline(date)}
        </h2>
        <DiaryFixEnglishDialog content={content} date={date} onApply={handleFixEnglishApply} />
      </div>

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
          className="relative h-full min-h-[400px] resize-none border-none bg-transparent p-0 text-base leading-8 text-transparent caret-foreground shadow-none focus-visible:ring-0"
          placeholder="Write today's entry…"
          ref={textareaRef}
          value={content}
          onChange={(e) => handleChange(e.target.value)}
          onScroll={syncMirrorScroll}
        />
      </div>

      <span className={cn("text-xs text-muted-foreground", !isPending && "invisible")}>Saving…</span>
    </div>
  );
}
