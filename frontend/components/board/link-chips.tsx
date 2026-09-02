"use client";

import { useState, useTransition } from "react";
import { Plus, X } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { createLinkAction, deleteLinkAction, type BoardTask, type LinkTargetType } from "@/lib/server/whatnow";
import type { DiaryEntryPreview } from "@/lib/server/diary";
import type { Project } from "@/lib/server/projects";

interface LinkChipsProps {
  task: BoardTask;
  allTasks: BoardTask[];
  diaryEntries: DiaryEntryPreview[];
  projects: Project[];
}

const TARGET_LABEL: Record<LinkTargetType, string> = {
  task: "Task",
  diary_entry: "Note",
  journal_entry: "Note",
  project: "Project",
};

export function LinkChips({ task, allTasks, diaryEntries, projects }: LinkChipsProps) {
  const [open, setOpen] = useState(false);
  const [, startTransition] = useTransition();

  function removeLink(linkId: string) {
    startTransition(async () => {
      await deleteLinkAction(linkId);
    });
  }

  return (
    <div className="flex flex-wrap items-center gap-1.5">
      {(task.links ?? []).map((link) => (
        <Badge className="gap-1 pr-1" key={link.id} variant="outline">
          {TARGET_LABEL[link.targetType]}: {link.targetLabel}
          <button
            aria-label={`Remove link to ${link.targetLabel}`}
            className="rounded-full hover:bg-foreground/10"
            type="button"
            onClick={() => removeLink(link.id)}
          >
            <X aria-hidden className="h-3 w-3" />
          </button>
        </Badge>
      ))}
      <Button className="h-6 gap-1 px-2 text-xs" size="sm" variant="ghost" onClick={() => setOpen(true)}>
        <Plus aria-hidden className="h-3 w-3" />
        Link
      </Button>
      <LinkPicker
        allTasks={allTasks}
        diaryEntries={diaryEntries}
        open={open}
        projects={projects}
        task={task}
        onOpenChange={setOpen}
      />
    </div>
  );
}

interface LinkPickerProps {
  task: BoardTask;
  allTasks: BoardTask[];
  diaryEntries: DiaryEntryPreview[];
  projects: Project[];
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

// Minimal link target picker: type tabs + a combobox over already-loaded
// page data (personal-scale lists) — no search endpoint needed.
function LinkPicker({ task, allTasks, diaryEntries, projects, open, onOpenChange }: LinkPickerProps) {
  const [type, setType] = useState<LinkTargetType>("task");
  const [, startTransition] = useTransition();

  function pick(targetId: string, targetLabel: string) {
    startTransition(async () => {
      await createLinkAction(task.id, type, targetId, targetLabel);
    });
    onOpenChange(false);
  }

  const options =
    type === "task"
      ? allTasks.filter((t) => t.id !== task.id).map((t) => ({ id: t.id, label: t.title }))
      : type === "diary_entry"
        ? diaryEntries.map((e) => ({ id: e.id, label: e.entry_date }))
        : projects.map((p) => ({ id: p.id, label: p.name }));

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="p-0">
        <DialogHeader className="p-4 pb-0">
          <DialogTitle>Link to…</DialogTitle>
        </DialogHeader>
        <Tabs value={type} onValueChange={(v) => setType(v as LinkTargetType)}>
          <TabsList className="mx-4">
            <TabsTrigger value="task">Task</TabsTrigger>
            <TabsTrigger value="diary_entry">Note</TabsTrigger>
            <TabsTrigger value="project">Project</TabsTrigger>
          </TabsList>
        </Tabs>
        <Command>
          <CommandInput placeholder="Search…" />
          <CommandList>
            <CommandEmpty>Nothing found.</CommandEmpty>
            <CommandGroup>
              {options.map((o) => (
                <CommandItem key={o.id} value={o.label} onSelect={() => pick(o.id, o.label)}>
                  {o.label}
                </CommandItem>
              ))}
            </CommandGroup>
          </CommandList>
        </Command>
      </DialogContent>
    </Dialog>
  );
}
