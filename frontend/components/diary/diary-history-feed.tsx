import Link from "next/link";
import { NotebookPen } from "lucide-react";

import type { DiaryEntryPreview } from "@/lib/server/diary";
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

// Date-wise entry feed, two-line preview each, each linking to that day's
// editable entry. One entry per day (the diary's own invariant), so no
// same-day grouping is needed here.
export function DiaryHistoryFeed({ entries }: DiaryHistoryFeedProps) {
  if (entries.length === 0) {
    return (
      <div className="empty-state">
        <NotebookPen aria-hidden className="empty-state-icon" />
        <p className="font-medium text-muted-foreground">No entries yet.</p>
        <p className="text-sm text-muted-foreground">Write today&apos;s entry to start your diary.</p>
      </div>
    );
  }

  return (
    <ol className="flex flex-col gap-8">
      {entries.map((entry) => (
        <li className="border-t border-border pt-4" key={entry.id}>
          <Link className="group block" href={ROUTES.diaryEntry(entry.entry_date)}>
            <time className="diary-paper-headline text-sm font-semibold uppercase tracking-wide text-primary">
              {formatLongDate(entry.entry_date)}
            </time>
            <p className="mt-2 line-clamp-2 text-base leading-8 text-foreground transition-colors duration-fast ease-smooth group-hover:text-muted-foreground">
              {entry.preview}
            </p>
          </Link>
        </li>
      ))}
    </ol>
  );
}
