import { getDiaryHistory } from "@/lib/server/diary";
import { getBoardAction, listTemplatesAction } from "@/lib/server/whatnow";
import { listProjectsAction } from "@/lib/server/projects";
import { BoardApp } from "@/components/board/board-app";

export const metadata = { title: "Board" };

export default async function BoardPage() {
  const [boardResult, templatesResult, projectsResult, diaryHistory] = await Promise.all([
    getBoardAction(),
    listTemplatesAction(),
    listProjectsAction(),
    getDiaryHistory({ limit: 20 }).catch(() => ({ entries: [], next_cursor: null })),
  ]);

  return (
    <BoardApp
      initialDiaryEntries={diaryHistory.entries}
      initialProjects={projectsResult.ok ? (projectsResult.data ?? []) : []}
      initialTasks={boardResult.ok ? (boardResult.data?.tasks ?? []) : []}
      initialTemplates={templatesResult.ok ? (templatesResult.data ?? []) : []}
    />
  );
}
