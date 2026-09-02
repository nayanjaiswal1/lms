import { getTodayEntry, getDiaryHistory, getDiaryTasks } from "@/lib/server/diary";
import { DiaryPageShell } from "@/components/diary/diary-page-shell";

export const metadata = { title: "Diary" };

export default async function DiaryPage() {
  const [entry, taskList, history] = await Promise.all([
    getTodayEntry(),
    getDiaryTasks({ done: false }),
    getDiaryHistory({ limit: 60 }),
  ]);

  return <DiaryPageShell entry={entry} historyEntries={history.entries} tasks={taskList.tasks} />;
}
