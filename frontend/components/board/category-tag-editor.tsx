"use client";

import { useTransition } from "react";

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { TagInput } from "@/components/ui/tag-input";
import { patchBoardTaskAction, type BoardTask } from "@/lib/server/whatnow";

// Fixed category set for the board's own create/edit UI only — the backend
// column stays free text so existing #hashtag categories from whatnow's
// capture parser keep working untouched.
const CATEGORIES = ["buy", "health", "learn", "research", "stuck", "other"] as const;

interface CategoryTagEditorProps {
  task: BoardTask;
}

// Both fields optional, patch fires on change — no save button, never blocks
// saving the task itself.
export function CategoryTagEditor({ task }: CategoryTagEditorProps) {
  const [, startTransition] = useTransition();

  function setCategory(value: string) {
    startTransition(async () => {
      await patchBoardTaskAction(task.id, { category: value === "none" ? "" : value });
    });
  }

  function setTags(tags: string[]) {
    startTransition(async () => {
      await patchBoardTaskAction(task.id, { tags });
    });
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      <Select defaultValue={task.category || "none"} onValueChange={setCategory}>
        <SelectTrigger className="h-8 w-auto min-w-28 text-xs">
          <SelectValue placeholder="Category" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="none">No category</SelectItem>
          {CATEGORIES.map((c) => (
            <SelectItem key={c} value={c}>
              {c}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      <TagInput
        className="h-8 min-h-8 w-auto flex-1 basis-40 py-1"
        placeholder="Add tag…"
        value={task.tags ?? []}
        onChange={setTags}
      />
    </div>
  );
}
