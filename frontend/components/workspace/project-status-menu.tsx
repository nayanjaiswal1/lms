"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { ChevronDown } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { setWorkspaceStatusAction } from "@/lib/workspace/actions";
import { PROJECT_STATUS_NEXT, type ProjectStatus } from "@/lib/workspace/types";
import { PROJECT_STATUS_LABEL, PROJECT_STATUS_VARIANT } from "@/lib/workspace/roles";

// Transitions that discard work in progress (recruiting/interests, active
// delivery) get a confirmation step; the rest (e.g. paused → active) don't
// need one.
const CONFIRM_TARGETS = new Set<ProjectStatus>(["cancelled", "completed", "archived"]);

interface ProjectStatusMenuProps {
  workspaceId: string;
  status: ProjectStatus;
  /** Owner only — callers gate this via useProjectRole().isOwner before rendering as interactive. */
  canChange: boolean;
}

export function ProjectStatusMenu({ workspaceId, status, canChange }: ProjectStatusMenuProps) {
  const [pending, startTransition] = useTransition();
  const [confirmTarget, setConfirmTarget] = useState<ProjectStatus | null>(null);
  const nextStatuses = PROJECT_STATUS_NEXT[status];

  function applyTransition(to: ProjectStatus) {
    startTransition(async () => {
      const result = await setWorkspaceStatusAction(workspaceId, to);
      setConfirmTarget(null);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success(`Status changed to ${PROJECT_STATUS_LABEL[to]}.`);
    });
  }

  function handleSelect(to: ProjectStatus) {
    if (CONFIRM_TARGETS.has(to)) {
      setConfirmTarget(to);
      return;
    }
    applyTransition(to);
  }

  if (!canChange || nextStatuses.length === 0) {
    return <Badge variant={PROJECT_STATUS_VARIANT[status]}>{PROJECT_STATUS_LABEL[status]}</Badge>;
  }

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button className="gap-1.5 px-3" disabled={pending} size="sm" variant="outline">
            <Badge className="pointer-events-none" variant={PROJECT_STATUS_VARIANT[status]}>
              {PROJECT_STATUS_LABEL[status]}
            </Badge>
            <ChevronDown aria-hidden className="h-3.5 w-3.5" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          {nextStatuses.map((to) => (
            <DropdownMenuItem key={to} onSelect={() => handleSelect(to)}>
              Move to {PROJECT_STATUS_LABEL[to]}
            </DropdownMenuItem>
          ))}
        </DropdownMenuContent>
      </DropdownMenu>

      <ConfirmDialog
        description={
          confirmTarget
            ? `This moves the workspace to "${PROJECT_STATUS_LABEL[confirmTarget]}". This may be irreversible or close out active work.`
            : ""
        }
        destructive={confirmTarget === "cancelled"}
        open={confirmTarget !== null}
        pending={pending}
        title={confirmTarget ? `Move to ${PROJECT_STATUS_LABEL[confirmTarget]}?` : "Change status?"}
        onConfirm={() => confirmTarget && applyTransition(confirmTarget)}
        onOpenChange={(open) => !open && setConfirmTarget(null)}
      />
    </>
  );
}
