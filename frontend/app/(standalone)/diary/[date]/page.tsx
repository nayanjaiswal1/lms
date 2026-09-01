import { getEntryByDate, getDiaryHistory } from "@/lib/server/diary";
import { getPlanInboxAction } from "@/lib/server/whatnow";
import { DiaryPageShell } from "@/components/diary/diary-page-shell";

export const metadata = { title: "Diary" };

interface DiaryDatePageProps {
  params: Promise<{ date: string }>;
}

// Editing a past day — reached from a calendar dot or a history feed entry,
// both of which only ever link to a date that already has an entry.
// Invalid/nonexistent dates throw from getEntryByDate straight to
// error.tsx, same as every other apiGet-backed page in this app.
export default async function DiaryDatePage({ params }: DiaryDatePageProps) {
  const { date } = await params;
  const [entry, inboxResult, history] = await Promise.all([
    getEntryByDate(date),
    getPlanInboxAction(),
    getDiaryHistory({ limit: 60 }),
  ]);
  const inbox = inboxResult.ok ? (inboxResult.data ?? []) : [];

  return <DiaryPageShell entry={entry} historyEntries={history.entries} inbox={inbox} />;
}
