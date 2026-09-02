"use client";

import { useState, useTransition } from "react";
import { ChevronDown, ChevronRight } from "lucide-react";

import { Checkbox } from "@/components/ui/checkbox";
import { patchBoardTaskAction, type BoardTask } from "@/lib/server/whatnow";
import type { DiaryEntryPreview } from "@/lib/server/diary";
import type { Project } from "@/lib/server/projects";
import { cn } from "@/lib/utils";

import { CategoryTagEditor } from "@/components/board/category-tag-editor";
import { UrgencyImportanceMenu } from "@/components/board/urgency-importance-menu";
import { LinkChips } from "@/components/board/link-chips";

interface BoardTaskRowProps {
  task: BoardTask;
  allTasks: BoardTask[];
  diaryEntries: DiaryEntryPreview[];
  projects: Project[];
}

// Checking a task strikes it through and keeps the row in place — never
// removed or deleted. Local optimistic state so the strike is instant; the
// prop resyncs it once the server action's revalidatePath lands.
export function BoardTaskRow({ task, allTasks, diaryEntries, projects }: BoardTaskRowProps) {
  const [optimisticDone, setOptimisticDone] = useState(task.status === "done");
  const [expanded, setExpanded] = useState(false);
  const [, startTransition] = useTransition();
  const isDone = task.status === "done" || optimisticDone;

  function toggle() {
    const next = !isDone;
    setOptimisticDone(next);
    startTransition(async () => {
      await patchBoardTaskAction(task.id, { status: next ? "done" : "inbox" });
    });
  }

  return (
    <li className="flex flex-col gap-2 rounded-md border border-border bg-card p-3">
      <div className="flex items-start gap-2.5">
        <Checkbox checked={isDone} className="mt-0.5" onCheckedChange={toggle} />
        <button
          className="flex flex-1 items-start gap-1.5 text-left"
          type="button"
          onClick={() => setExpanded((e) => !e)}
        >
          <span
            className={cn(
              "flex-1 text-sm text-foreground",
              isDone && "text-muted-foreground line-through",
            )}
          >
            {task.title}
          </span>
          {task.body && (
            expanded
              ? <ChevronDown aria-hidden className="mt-0.5 h-4 w-4 shrink-0 text-muted-foreground" />
              : <ChevronRight aria-hidden className="mt-0.5 h-4 w-4 shrink-0 text-muted-foreground" />
          )}
        </button>
      </div>

      {expanded && task.body && (
        <p className="ml-7 whitespace-pre-line rounded-md bg-muted/50 p-2 text-xs text-muted-foreground">
          {task.body}
        </p>
      )}

      <div className="ml-7 flex flex-col gap-2">
        <div className="flex flex-wrap items-center gap-2">
          <CategoryTagEditor task={task} />
          <UrgencyImportanceMenu task={task} />
        </div>
        <LinkChips allTasks={allTasks} diaryEntries={diaryEntries} projects={projects} task={task} />
      </div>
    </li>
  );
}
