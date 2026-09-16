import { diarySerif } from "@/components/diary/diary-fonts";
import { journalSans } from "@/components/habits/journal-fonts";
import "@/components/diary/diary-theme.css";
import { DiaryEditor } from "@/components/diary/diary-editor";
import { DiaryGoalsSection } from "@/components/diary/diary-goals-section";
import { DiaryTasksSection } from "@/components/diary/diary-tasks-section";
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
// feed either way; only how the caller fetches `entry` differs. Layout is
// the .diary-shell grid (diary-theme.css): calendar/goals/editor/tasks
// stack in that order on mobile, and split into a 3-column
// calendar+goals-rail / editor / tasks-rail layout at lg+ — see that file
// for why Tasks moves to its own column instead of stacking under Goals.
export function DiaryPageShell({ entry, tasks, historyEntries }: DiaryPageShellProps) {
  return (
    <div className={cn("diary-paper min-h-dvh p-4 sm:p-6 lg:p-8", journalSans.variable, diarySerif.variable)}>
      <div className="diary-shell">
        <div className="diary-shell-calendar lg:sticky lg:top-8">
          <DiaryCalendar entries={historyEntries} />
        </div>

        <div className="diary-shell-goals lg:sticky lg:top-8">
          <DiaryGoalsSection date={entry.entry_date} goals={entry.goals} />
        </div>

        <div className="diary-shell-editor">
          <DiaryEditor
            date={entry.entry_date}
            highlights={entry.highlights}
            historyContent={<DiaryHistoryFeed entries={historyEntries} />}
            initialContent={entry.content}
          />
        </div>

        <div className="diary-shell-tasks lg:sticky lg:top-8">
          <DiaryTasksSection tasks={tasks} />
        </div>
      </div>
    </div>
  );
}
