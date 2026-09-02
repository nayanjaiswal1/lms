"use client";

import { useTransition } from "react";
import { Flame, Star } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { patchBoardTaskAction, type BoardTask } from "@/lib/server/whatnow";
import { cn } from "@/lib/utils";

interface UrgencyImportanceMenuProps {
  task: BoardTask;
}

// Two inline dropdowns (no drag-and-drop, per requirement 5) that set the
// 2x2 matrix axes. Either can be cleared independently via "Not set" — a
// task missing either axis stays list-only in the matrix tab.
export function UrgencyImportanceMenu({ task }: UrgencyImportanceMenuProps) {
  const [, startTransition] = useTransition();

  function setUrgency(value: string) {
    startTransition(async () => {
      await patchBoardTaskAction(task.id, { urgency: value === "unset" ? "" : (value as "urgent" | "not_urgent") });
    });
  }

  function setImportance(value: string) {
    startTransition(async () => {
      await patchBoardTaskAction(task.id, {
        importance: value === "unset" ? "" : (value as "important" | "not_important"),
      });
    });
  }

  return (
    <div className="flex items-center gap-1.5">
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            className={cn("h-7 gap-1 px-2 text-xs", task.urgency && "text-primary")}
            size="sm"
            variant="outline"
          >
            <Flame aria-hidden className="h-3.5 w-3.5" />
            {task.urgency === "urgent" ? "Urgent" : task.urgency === "not_urgent" ? "Not urgent" : "Urgency"}
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start">
          <DropdownMenuRadioGroup value={task.urgency ?? "unset"} onValueChange={setUrgency}>
            <DropdownMenuRadioItem value="urgent">Urgent</DropdownMenuRadioItem>
            <DropdownMenuRadioItem value="not_urgent">Not urgent</DropdownMenuRadioItem>
            <DropdownMenuRadioItem value="unset">Not set</DropdownMenuRadioItem>
          </DropdownMenuRadioGroup>
        </DropdownMenuContent>
      </DropdownMenu>

      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            className={cn("h-7 gap-1 px-2 text-xs", task.importance && "text-primary")}
            size="sm"
            variant="outline"
          >
            <Star aria-hidden className="h-3.5 w-3.5" />
            {task.importance === "important"
              ? "Important"
              : task.importance === "not_important"
                ? "Not important"
                : "Importance"}
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start">
          <DropdownMenuRadioGroup value={task.importance ?? "unset"} onValueChange={setImportance}>
            <DropdownMenuRadioItem value="important">Important</DropdownMenuRadioItem>
            <DropdownMenuRadioItem value="not_important">Not important</DropdownMenuRadioItem>
            <DropdownMenuRadioItem value="unset">Not set</DropdownMenuRadioItem>
          </DropdownMenuRadioGroup>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}
