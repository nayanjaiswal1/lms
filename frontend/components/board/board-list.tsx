import type { BoardTask } from "@/lib/server/whatnow";
import type { DiaryEntryPreview } from "@/lib/server/diary";
import type { Project } from "@/lib/server/projects";

import { BoardTaskRow } from "@/components/board/board-task-row";

interface BoardListProps {
  tasks: BoardTask[];
  diaryEntries: DiaryEntryPreview[];
  projects: Project[];
}

// Flat list, default view — no grouping or sort controls (requirement 7).
export function BoardList({ tasks, diaryEntries, projects }: BoardListProps) {
  if (tasks.length === 0) {
    return <p className="py-10 text-center text-sm text-muted-foreground">Nothing here yet. Add something above.</p>;
  }
  return (
    <ul className="flex flex-col gap-2">
      {tasks.map((task) => (
        <BoardTaskRow allTasks={tasks} diaryEntries={diaryEntries} key={task.id} projects={projects} task={task} />
      ))}
    </ul>
  );
}
