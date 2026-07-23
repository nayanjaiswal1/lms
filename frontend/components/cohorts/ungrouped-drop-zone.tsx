"use client";

import { useRef } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { moveBatchToGroupAction } from "@/app/(app)/cohort-groups/actions";

const DROP_HIGHLIGHT = ["ring-2", "ring-primary", "bg-primary/5"];

// Drop target for pulling a batch card out of every group — the tree itself
// has no "no group" node to drop on.
export function UngroupedDropZone() {
  const ref = useRef<HTMLDivElement>(null);
  const router = useRouter();

  async function handleDrop(e: React.DragEvent) {
    e.preventDefault();
    ref.current?.classList.remove(...DROP_HIGHLIGHT);
    const batchId = e.dataTransfer.getData("text/plain");
    if (!batchId) return;
    const res = await moveBatchToGroupAction(batchId, null);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Batch ungrouped.");
    router.refresh();
  }

  return (
    <div
      className="rounded-md border border-dashed border-border px-3 py-2 text-sm text-muted-foreground"
      ref={ref}
      onDragEnter={(e) => {
        e.preventDefault();
        ref.current?.classList.add(...DROP_HIGHLIGHT);
      }}
      onDragLeave={() => ref.current?.classList.remove(...DROP_HIGHLIGHT)}
      onDragOver={(e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = "move";
      }}
      onDrop={handleDrop}
    >
      Drop here to ungroup
    </div>
  );
}
