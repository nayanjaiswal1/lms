"use client";

import { useState, useTransition, type KeyboardEvent } from "react";

import { Input } from "@/components/ui/input";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { captureBoardTaskAction, type BoardTask, type TaskTemplate } from "@/lib/server/whatnow";
import type { DiaryEntryPreview } from "@/lib/server/diary";
import type { Project } from "@/lib/server/projects";

import { BoardList } from "@/components/board/board-list";
import { BoardMatrix } from "@/components/board/board-matrix";
import { TemplateControls } from "@/components/board/template-dialogs";

interface BoardAppProps {
  initialTasks: BoardTask[];
  initialTemplates: TaskTemplate[];
  initialProjects: Project[];
  initialDiaryEntries: DiaryEntryPreview[];
}

// Root of the Linked Task Board: flat list by default, a matrix tab
// switched in-page (local state, not a route), quick-capture, and template
// controls. Minimal chrome per requirement 7.
export function BoardApp({ initialTasks, initialTemplates, initialProjects, initialDiaryEntries }: BoardAppProps) {
  const [draft, setDraft] = useState("");
  const [, startTransition] = useTransition();

  function submitDraft() {
    const raw = draft.trim();
    if (!raw) return;
    setDraft("");
    startTransition(async () => {
      await captureBoardTaskAction(raw);
    });
  }

  function onKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Enter") submitDraft();
  }

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-6 px-4 py-10">
      <div>
        <h1 className="text-2xl font-semibold text-foreground">Board</h1>
        <p className="text-sm text-muted-foreground">Everything in one place — check it off, it stays here.</p>
      </div>

      <Input
        placeholder="Add something… (e.g. buy raincoat #buy, by friday)"
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        onKeyDown={onKeyDown}
      />

      <TemplateControls templates={initialTemplates} />

      <Tabs defaultValue="list">
        <TabsList>
          <TabsTrigger value="list">List</TabsTrigger>
          <TabsTrigger value="matrix">Matrix</TabsTrigger>
        </TabsList>
        <TabsContent value="list">
          <BoardList diaryEntries={initialDiaryEntries} projects={initialProjects} tasks={initialTasks} />
        </TabsContent>
        <TabsContent value="matrix">
          <BoardMatrix diaryEntries={initialDiaryEntries} projects={initialProjects} tasks={initialTasks} />
        </TabsContent>
      </Tabs>
    </div>
  );
}
