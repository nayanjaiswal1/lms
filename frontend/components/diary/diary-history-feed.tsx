"use client";

import { useState } from "react";
import Link from "next/link";
import { NotebookPen } from "lucide-react";

import { apiFetch } from "@/lib/client/api";
import type { DiaryEntry, DiaryEntryPreview } from "@/lib/server/diary";
import ROUTES from "@/lib/routes";

interface DiaryHistoryFeedProps {
  entries: DiaryEntryPreview[];
}

function formatLongDate(date: string): string {
  return new Date(`${date}T00:00:00`).toLocaleDateString(undefined, {
    month: "long",
    day: "numeric",
    year: "numeric",
  });
}

interface OpenEntry {
  date: string;
  content: string | null; // null while the full entry is loading
}

// Date-wise entry feed, one-line preview each. Clicking a date expands it in
// place to the full entry text (fetched on demand — the history list only
// ever carries a truncated preview, see backend previewOf) instead of
// navigating to the editable /diary/{date} page, so browsing old entries
// can't accidentally put one into edit mode.
export function DiaryHistoryFeed({ entries }: DiaryHistoryFeedProps) {
  const [open, setOpen] = useState<OpenEntry | null>(null);

  if (entries.length === 0) {
    return (
      <div className="empty-state">
        <NotebookPen aria-hidden className="empty-state-icon" />
        <p className="font-medium text-muted-foreground">No entries yet.</p>
        <p className="text-sm text-muted-foreground">Write today&apos;s entry to start your diary.</p>
      </div>
    );
  }

  async function toggle(date: string) {
    if (open?.date === date) {
      setOpen(null);
      return;
    }
    setOpen({ date, content: null });
    const entry = await apiFetch<DiaryEntry>(`/diary/${date}`);
    setOpen({ date, content: entry?.content ?? "" });
  }

  return (
    <ol className="flex flex-col gap-8">
      {entries.map((entry) => {
        const expanded = open?.date === entry.entry_date;
        return (
          <li className="border-t border-border pt-4" key={entry.id}>
            <button
              aria-expanded={expanded}
              className="group block w-full text-left"
              type="button"
              onClick={() => toggle(entry.entry_date)}
            >
              <time className="diary-paper-headline text-sm font-semibold uppercase tracking-wide text-primary">
                {formatLongDate(entry.entry_date)}
              </time>
              {expanded ? (
                <p className="mt-2 whitespace-pre-wrap text-base leading-8 text-foreground">
                  {open?.content === null ? "Loading…" : open.content}
                </p>
              ) : (
                <p className="mt-2 line-clamp-1 text-base leading-8 text-foreground transition-colors duration-fast ease-smooth group-hover:text-muted-foreground">
                  {entry.preview}
                </p>
              )}
            </button>
            {expanded && (
              <Link
                className="mt-2 inline-block text-xs text-muted-foreground underline-offset-2 hover:underline"
                href={ROUTES.diaryEntry(entry.entry_date)}
              >
                Edit this entry
              </Link>
            )}
          </li>
        );
      })}
    </ol>
  );
}
