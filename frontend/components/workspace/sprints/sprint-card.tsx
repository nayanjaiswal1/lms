"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { CloseSprintDialog } from "@/components/workspace/sprints/close-sprint-dialog";
import { startSprintAction } from "@/lib/workspace/phase5-actions";
import type { Sprint, SprintStatus } from "@/lib/workspace/types";

const STATUS_VARIANT: Record<SprintStatus, "default" | "secondary" | "outline"> = {
  planned: "outline",
  active: "default",
  completed: "secondary",
};

interface SprintCardProps {
  workspaceId: string;
  sprint: Sprint;
  plannedSprints: Sprint[];
  canManage: boolean;
}

export function SprintCard({ workspaceId, sprint, plannedSprints, canManage }: SprintCardProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [closing, setClosing] = useState(false);

  function start() {
    startTransition(async () => {
      const result = await startSprintAction(workspaceId, sprint.id);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success("Sprint started.");
      router.refresh();
    });
  }

  return (
    <div className="card-base flex flex-wrap items-center justify-between gap-3">
      <div className="min-w-0">
        <div className="flex items-center gap-2">
          <p className="truncate font-medium">{sprint.name}</p>
          <Badge variant={STATUS_VARIANT[sprint.status]}>{sprint.status}</Badge>
        </div>
        <p className="text-xs text-muted-foreground">
          {sprint.starts_on} → {sprint.ends_on} · {sprint.done}/{sprint.committed} done
        </p>
      </div>
      {canManage && sprint.status === "planned" && (
        <Button disabled={pending} size="sm" onClick={start}>
          {pending ? "Starting…" : "Start"}
        </Button>
      )}
      {canManage && sprint.status === "active" && (
        <Button size="sm" variant="outline" onClick={() => setClosing(true)}>
          Close
        </Button>
      )}
      <CloseSprintDialog
        nextSprints={plannedSprints.filter((s) => s.id !== sprint.id)}
        open={closing}
        sprintId={sprint.id}
        workspaceId={workspaceId}
        onOpenChange={setClosing}
      />
    </div>
  );
}
