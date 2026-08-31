import Link from "next/link";
import { History } from "lucide-react";

import { getTodayEntry } from "@/lib/server/diary";
import { getPlanInboxAction } from "@/lib/server/whatnow";
import { diarySerif } from "@/components/diary/diary-fonts";
import { journalSans } from "@/components/habits/journal-fonts";
import "@/components/diary/diary-theme.css";
import { DiaryEditor } from "@/components/diary/diary-editor";
import { DiaryTodayLists } from "@/components/diary/diary-today-lists";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Diary" };

export default async function DiaryPage() {
  const [entry, inboxResult] = await Promise.all([getTodayEntry(), getPlanInboxAction()]);
  const inbox = inboxResult.ok ? (inboxResult.data ?? []) : [];

  return (
    <div className={cn("diary-paper min-h-full p-4 sm:p-6 lg:p-8", journalSans.variable, diarySerif.variable)}>
      <main className="page-container-sm relative">
        <Link
          aria-label="Diary history"
          className="touch-target absolute right-4 top-4 z-raised flex items-center justify-center rounded-full border border-border bg-background text-foreground shadow-card transition-colors duration-fast ease-smooth hover:bg-accent sm:right-6 sm:top-6"
          href={ROUTES.DIARY_HISTORY}
        >
          <History aria-hidden className="size-5" />
        </Link>

        <DiaryEditor date={entry.entry_date} highlights={entry.highlights} initialContent={entry.content} />

        <div className="mt-10">
          <DiaryTodayLists tasks={inbox} />
        </div>
      </main>
    </div>
  );
}
