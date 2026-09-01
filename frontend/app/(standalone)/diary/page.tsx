import { getTodayEntry, getDiaryHistory } from "@/lib/server/diary";
import { getPlanInboxAction } from "@/lib/server/whatnow";
import { DiaryPageShell } from "@/components/diary/diary-page-shell";

export const metadata = { title: "Diary" };

export default async function DiaryPage() {
  const [entry, inboxResult, history] = await Promise.all([
    getTodayEntry(),
    getPlanInboxAction(),
    getDiaryHistory({ limit: 60 }),
  ]);
  const inbox = inboxResult.ok ? (inboxResult.data ?? []) : [];

  return <DiaryPageShell entry={entry} historyEntries={history.entries} inbox={inbox} />;
}
