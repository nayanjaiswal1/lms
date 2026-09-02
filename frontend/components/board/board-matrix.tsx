import type { BoardTask } from "@/lib/server/whatnow";
import type { DiaryEntryPreview } from "@/lib/server/diary";
import type { Project } from "@/lib/server/projects";

import { BoardTaskRow } from "@/components/board/board-task-row";

interface BoardMatrixProps {
  tasks: BoardTask[];
  diaryEntries: DiaryEntryPreview[];
  projects: Project[];
}

const QUADRANTS = [
  { label: "Do first", urgency: "urgent", importance: "important" },
  { label: "Schedule", urgency: "not_urgent", importance: "important" },
  { label: "Delegate", urgency: "urgent", importance: "not_important" },
  { label: "Eliminate", urgency: "not_urgent", importance: "not_important" },
] as const;

// Urgency/importance on each task are the source of truth (set via the
// inline dropdowns on the row, no drag-and-drop) — this view only buckets
// them into the 2x2 grid. A task missing either axis stays out of the grid
// entirely, shown in a separate strip below so nothing silently disappears.
export function BoardMatrix({ tasks, diaryEntries, projects }: BoardMatrixProps) {
  const unsorted = tasks.filter((t) => !t.urgency || !t.importance);

  return (
    <div className="flex flex-col gap-6">
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        {QUADRANTS.map((q) => {
          const items = tasks.filter((t) => t.urgency === q.urgency && t.importance === q.importance);
          return (
            <div className="flex flex-col gap-2 rounded-lg border border-border p-3" key={q.label}>
              <h3 className="text-sm font-semibold text-foreground">{q.label}</h3>
              {items.length === 0 ? (
                <p className="text-xs text-muted-foreground">Nothing here.</p>
              ) : (
                <ul className="flex flex-col gap-2">
                  {items.map((task) => (
                    <BoardTaskRow
                      allTasks={tasks}
                      diaryEntries={diaryEntries}
                      key={task.id}
                      projects={projects}
                      task={task}
                    />
                  ))}
                </ul>
              )}
            </div>
          );
        })}
      </div>

      {unsorted.length > 0 && (
        <div className="flex flex-col gap-2">
          <h3 className="text-sm font-semibold text-muted-foreground">Unsorted (set urgency + importance to place)</h3>
          <ul className="flex flex-col gap-2">
            {unsorted.map((task) => (
              <BoardTaskRow
                allTasks={tasks}
                diaryEntries={diaryEntries}
                key={task.id}
                projects={projects}
                task={task}
              />
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
