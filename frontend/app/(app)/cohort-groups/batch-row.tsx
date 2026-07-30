"use client";

import { useState } from "react";
import Link from "next/link";
import { MessageSquare } from "lucide-react";

import { BatchAvatar } from "@/components/batches/batch-avatar";
import { Button } from "@/components/ui/button";
import { MoveBatchSelect } from "@/app/(app)/cohort-groups/move-batch-select";
import { EditBatchPanel } from "@/app/(app)/batches/[id]/edit-batch-panel";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";
import type { Batch, OrgMemberSummary } from "@/lib/server/batches";
import type { FlatCohortOption } from "@/lib/server/cohorts";

interface BatchRowProps {
  batch: Batch;
  options: FlatCohortOption[];
  orgMembers: OrgMemberSummary[];
  depth?: number;
}

// Compact draggable row for a batch nested under its group in the hierarchy
// tree — dragging moves it between groups (plain batch id over
// "text/plain"), the select and edit icon are the keyboard/touch-accessible
// equivalents.
export function BatchRow({ batch, options, orgMembers, depth = 0 }: BatchRowProps) {
  const [dragging, setDragging] = useState(false);

  return (
    <div
      draggable
      className={cn(
        "flex flex-col gap-2 rounded-md p-2 cursor-grab active:cursor-grabbing sm:flex-row sm:items-center sm:justify-between",
        "hover:bg-muted",
        dragging && "opacity-50",
      )}
      // eslint-disable-next-line no-restricted-syntax -- tree indent depth is unbounded/dynamic, can't be a fixed Tailwind class
      style={{ paddingLeft: `${depth * 14 + 28}px` }}
      onDragEnd={() => setDragging(false)}
      onDragStart={(e) => {
        e.dataTransfer.setData("text/plain", batch.id);
        e.dataTransfer.effectAllowed = "move";
        setDragging(true);
      }}
    >
      <Link className="flex min-w-0 items-center gap-2" href={ROUTES.batch(batch.id)}>
        <BatchAvatar batchId={batch.id} imageUrl={batch.image_url} name={batch.name} />
        <span className="truncate text-sm font-medium">{batch.name}</span>
        <span className="shrink-0 text-xs text-muted-foreground">{batch.member_count} members</span>
      </Link>
      <div className="flex items-center gap-1.5">
        <MoveBatchSelect batchId={batch.id} batchName={batch.name} className="w-full sm:w-[200px]" currentGroupId={batch.cohort_group_id} options={options} />
        <Button aria-label={`Open chat for ${batch.name}`} asChild size="icon" variant="ghost">
          <Link href={`${ROUTES.batch(batch.id)}/chat`}>
            <MessageSquare aria-hidden className="h-3.5 w-3.5" />
          </Link>
        </Button>
        <EditBatchPanel batch={batch} orgMembers={orgMembers} triggerSize="icon" triggerVariant="ghost" />
      </div>
    </div>
  );
}
