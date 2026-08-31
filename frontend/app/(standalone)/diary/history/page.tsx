import Link from "next/link";
import { PenLine } from "lucide-react";

import { getDiaryHistory } from "@/lib/server/diary";
import { diarySerif } from "@/components/diary/diary-fonts";
import { journalSans } from "@/components/habits/journal-fonts";
import "@/components/diary/diary-theme.css";
import { DiaryHistoryTimeline } from "@/components/diary/diary-history-timeline";
import { DiaryHistoryChronicle } from "@/components/diary/diary-history-chronicle";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Diary History" };

export default async function DiaryHistoryPage() {
  const { entries } = await getDiaryHistory({ limit: 60 });

  return (
    <div className={cn("diary-paper min-h-full p-4 sm:p-6 lg:p-8", journalSans.variable, diarySerif.variable)}>
      <main className="page-container relative">
        <div className="page-header">
          <h1 className="diary-paper-headline page-title">History</h1>
          <Link
            aria-label="Write today's entry"
            className="touch-target flex items-center justify-center rounded-full border border-border bg-background text-foreground shadow-card transition-colors duration-fast ease-smooth hover:bg-accent"
            href={ROUTES.DIARY}
          >
            <PenLine aria-hidden className="size-5" />
          </Link>
        </div>

        <div className="lg:hidden">
          <DiaryHistoryTimeline entries={entries} />
        </div>
        <div className="hidden lg:block">
          <DiaryHistoryChronicle entries={entries} />
        </div>
      </main>
    </div>
  );
}
