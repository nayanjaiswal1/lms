"use client";

import dynamic from "next/dynamic";
import { ListTree } from "lucide-react";

import { Skeleton } from "@/components/ui/skeleton";
import type { BurndownCheckpoint } from "@/lib/projects/types";

const AssignmentBurndownInner = dynamic(() => import("@/components/projects/assignment-burndown-inner"), {
  ssr: false,
  loading: () => <Skeleton className="h-52 w-full" />,
});

interface AssignmentBurndownProps {
  checkpoints: BurndownCheckpoint[];
}

// GET /api/projects/assignments/{assignmentID}/burndown legitimately returns
// an empty checkpoint list today — project_checkpoints has no rows until
// Batch 5 ships checkpoint CRUD and milestone->checkpoint issue mapping. This
// is that clean empty state, not a workaround for a bug.
export function AssignmentBurndown({ checkpoints }: AssignmentBurndownProps) {
  if (checkpoints.length === 0) {
    return (
      <div className="empty-state py-10">
        <ListTree aria-hidden className="empty-state-icon" />
        <p className="text-sm text-muted-foreground">No checkpoints configured yet.</p>
        <p className="text-xs text-muted-foreground">
          The burndown fills in once this assignment has checkpoints with linked issues.
        </p>
      </div>
    );
  }
  return <AssignmentBurndownInner checkpoints={checkpoints} />;
}
