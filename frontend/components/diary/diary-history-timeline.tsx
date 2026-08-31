import { NotebookPen } from "lucide-react";

import type { DiaryEntryPreview } from "@/lib/server/diary";

interface DiaryHistoryTimelineProps {
  entries: DiaryEntryPreview[];
}

function formatShortDate(date: string): string {
  return new Date(`${date}T00:00:00`).toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

// Mobile history view: a plain read-only timeline. One entry per day (the
// diary's own invariant), so no same-day grouping is needed here — unlike
// the Learning Journal timeline this mirrors.
export function DiaryHistoryTimeline({ entries }: DiaryHistoryTimelineProps) {
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
    <ol className="flex flex-col">
      {entries.map((entry) => (
        <li className="flex flex-col gap-1 border-b border-border py-4 first:pt-0" key={entry.id}>
          <span className="diary-paper-headline text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            {formatShortDate(entry.entry_date)}
          </span>
          <p className="line-clamp-1 text-base text-foreground">{entry.preview}</p>
        </li>
      ))}
    </ol>
  );
}
