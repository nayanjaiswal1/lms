import { diarySerif } from "@/components/diary/diary-fonts";
import { journalSans } from "@/components/habits/journal-fonts";
import "@/components/diary/diary-theme.css";
import { DiaryEditor } from "@/components/diary/diary-editor";
import { DiaryTodayLists } from "@/components/diary/diary-today-lists";
import { DiaryCalendar } from "@/components/diary/diary-calendar";
import { DiaryHistoryFeed } from "@/components/diary/diary-history-feed";
import { cn } from "@/lib/utils";
import type { DiaryEntry, DiaryEntryPreview, DiaryTask } from "@/lib/server/diary";

interface DiaryPageShellProps {
  entry: DiaryEntry;
  tasks: DiaryTask[];
  historyEntries: DiaryEntryPreview[];
}

// Shared by /diary (today, get-or-create) and /diary/[date] (edit any past
// day with an existing entry) — same write surface, calendar, and history
// feed either way; only how the caller fetches `entry` differs.
export function DiaryPageShell({ entry, tasks, historyEntries }: DiaryPageShellProps) {
  return (
    <div className={cn("diary-paper min-h-dvh p-4 sm:p-6 lg:p-8", journalSans.variable, diarySerif.variable)}>
      <div className="page-container lg:grid lg:grid-cols-[280px_1fr] lg:items-start lg:gap-10">
        <aside className="flex flex-col gap-8 lg:sticky lg:top-8">
          <DiaryCalendar entries={historyEntries} />
          <DiaryTodayLists goals={entry.goals} tasks={tasks} />
        </aside>

        <div className="mt-10 max-w-3xl lg:mt-0">
          <DiaryEditor date={entry.entry_date} highlights={entry.highlights} initialContent={entry.content} />

          <div className="mt-12 border-t border-border pt-8">
            <h2 className="diary-paper-headline page-title mb-4 text-xl">History</h2>
            <DiaryHistoryFeed entries={historyEntries} />
          </div>
        </div>
      </div>
    </div>
  );
}
