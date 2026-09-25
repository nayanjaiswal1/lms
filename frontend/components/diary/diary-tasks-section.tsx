"use client";

import { useMemo, useState, useTransition } from "react";

import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import { createDiaryTaskAction, toggleDiaryTaskAction, updateDiaryTaskDetailsAction } from "@/app/(app)/diary/actions";
import type { DiaryTask, DiaryTaskKind } from "@/lib/server/diary";

interface DiaryTasksSectionProps {
  tasks: DiaryTask[];
}

// Diary's own todo/buy checklist — diary_tasks, no dependency on What Now?.
// Checking a task crosses it out instead of removing it; tags filter which
// tasks show. Split from Goals (see DiaryGoalsSection) so DiaryPageShell can
// place the two independently in its layout grid — Tasks sits in its own
// right-hand column on large screens instead of stacking under Goals.
export function DiaryTasksSection({ tasks }: DiaryTasksSectionProps) {
  const [items, setItems] = useState(tasks);
  const [activeTag, setActiveTag] = useState<string | null>(null);
  const [, startTransition] = useTransition();

  const allTags = useMemo(() => Array.from(new Set(items.flatMap((t) => t.tags))).sort(), [items]);
  const visible = activeTag ? items.filter((t) => t.tags.includes(activeTag)) : items;
  const buyItems = visible.filter((t) => t.kind === "buy");
  const todoItems = visible.filter((t) => t.kind === "todo");

  function handleCheck(id: string, done: boolean) {
    setItems((prev) => prev.map((t) => (t.id === id ? { ...t, done } : t)));
    startTransition(async () => {
      await toggleDiaryTaskAction(id, done);
    });
  }

  function handleSaveDetails(id: string, title: string, description: string) {
    setItems((prev) => prev.map((t) => (t.id === id ? { ...t, title, description } : t)));
    startTransition(async () => {
      await updateDiaryTaskDetailsAction(id, title, description);
    });
  }

  function handleAdd(kind: DiaryTaskKind, title: string) {
    startTransition(async () => {
      const { ok, data } = await createDiaryTaskAction(title, kind, activeTag ? [activeTag] : []);
      if (ok && data) setItems((prev) => [...prev, data]);
    });
  }

  return (
    <div className="flex flex-col gap-6">
      {allTags.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          <Button
            aria-pressed={activeTag === null}
            className={cn("touch-target px-2.5 text-xs", activeTag === null && "bg-accent")}
            size="sm"
            type="button"
            variant="ghost"
            onClick={() => setActiveTag(null)}
          >
            All
          </Button>
          {allTags.map((tag) => (
            <Button
              aria-pressed={activeTag === tag}
              className={cn("touch-target px-2.5 text-xs", activeTag === tag && "bg-accent text-primary")}
              key={tag}
              size="sm"
              type="button"
              variant="ghost"
              onClick={() => setActiveTag(tag)}
            >
              {tag}
            </Button>
          ))}
        </div>
      )}

      <TaskSection
        items={todoItems}
        title="To-Do"
        onAdd={(title) => handleAdd("todo", title)}
        onCheck={handleCheck}
        onSaveDetails={handleSaveDetails}
      />
      <TaskSection
        items={buyItems}
        title="Buy List"
        onAdd={(title) => handleAdd("buy", title)}
        onCheck={handleCheck}
        onSaveDetails={handleSaveDetails}
      />
    </div>
  );
}

interface TaskSectionProps {
  title: string;
  items: DiaryTask[];
  onAdd: (title: string) => void;
  onCheck: (id: string, done: boolean) => void;
  onSaveDetails: (id: string, title: string, description: string) => void;
}

// Clicking a task expands it into an editable title + description in place
// — AI-captured titles are sometimes cut mid-sentence (the analyze pass ran
// against text the writer hadn't finished typing yet), and there was
// previously no way to see or fix the full text, let alone attach any more
// detail, short of editing the DB row. The section always renders (even
// with zero items) so there's somewhere to add one manually — diary_tasks
// aren't only AI-captured.
function TaskSection({ title, items, onAdd, onCheck, onSaveDetails }: TaskSectionProps) {
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draft, setDraft] = useState({ title: "", description: "" });

  function startEdit(task: DiaryTask) {
    setEditingId(task.id);
    setDraft({ title: task.title, description: task.description });
  }

  function confirmEdit() {
    const trimmedTitle = draft.title.trim();
    if (editingId && trimmedTitle !== "") onSaveDetails(editingId, trimmedTitle, draft.description.trim());
    setEditingId(null);
  }

  return (
    <div className="border-t border-border pt-4">
      <h3 className="diary-paper-headline mb-3 text-lg font-semibold text-foreground">{title}</h3>
      <ul className="flex flex-col gap-2">
        {items.map((task) => (
          <li className="flex items-start gap-2.5" key={task.id}>
            <Checkbox
              checked={task.done}
              className="mt-0.5"
              id={`diary-task-${task.id}`}
              onCheckedChange={(checked) => onCheck(task.id, checked === true)}
            />
            {editingId === task.id ? (
              <div className="flex flex-1 flex-col gap-1.5">
                <Input
                  className="text-sm"
                  ref={(el) => el?.focus()}
                  value={draft.title}
                  onChange={(e) => setDraft((d) => ({ ...d, title: e.target.value }))}
                />
                <Textarea
                  className="min-h-16 text-sm"
                  placeholder="Add a description…"
                  value={draft.description}
                  onChange={(e) => setDraft((d) => ({ ...d, description: e.target.value }))}
                />
                <div className="flex gap-2">
                  <Button size="sm" onClick={confirmEdit}>
                    Save
                  </Button>
                  <Button size="sm" variant="ghost" onClick={() => setEditingId(null)}>
                    Cancel
                  </Button>
                </div>
              </div>
            ) : (
              <button
                className="flex-1 text-left"
                type="button"
                onClick={() => startEdit(task)}
              >
                <span className={cn("block text-sm text-foreground", task.done && "text-muted-foreground line-through")}>
                  {task.title}
                </span>
                {task.description && (
                  <span className="mt-0.5 block text-xs text-muted-foreground">{task.description}</span>
                )}
              </button>
            )}
          </li>
        ))}
        <AddTaskRow onAdd={onAdd} />
      </ul>
    </div>
  );
}

interface AddTaskRowProps {
  onAdd: (title: string) => void;
}

function AddTaskRow({ onAdd }: AddTaskRowProps) {
  const [title, setTitle] = useState("");

  function submit() {
    const trimmed = title.trim();
    if (trimmed === "") return;
    onAdd(trimmed);
    setTitle("");
  }

  return (
    <li className="flex items-center gap-2">
      <Input
        className="flex-1 text-sm"
        placeholder="Add…"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            e.preventDefault();
            submit();
          }
        }}
      />
      <Button size="sm" type="button" variant="ghost" onClick={submit}>
        Add
      </Button>
    </li>
  );
}
