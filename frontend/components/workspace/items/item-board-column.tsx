"use client";

import { Badge } from "@/components/ui/badge";
import { ItemCard } from "@/components/workspace/items/item-card";
import { ITEM_STATUS_LABEL, ITEM_STATUS_VARIANT } from "@/lib/workspace/items-constants";
import type { ItemStatus, WorkItem } from "@/lib/workspace/types";

interface ItemBoardColumnProps {
  workspaceId: string;
  status: ItemStatus;
  items: WorkItem[];
  canTransition: boolean;
  wipLimit: number;
  wipCounts: Record<string, number>;
}

export function ItemBoardColumn({ workspaceId, status, items, canTransition, wipLimit, wipCounts }: ItemBoardColumnProps) {
  return (
    <div className="flex min-w-0 flex-col gap-2">
      <div className="flex items-center gap-2">
        <Badge variant={ITEM_STATUS_VARIANT[status]}>{ITEM_STATUS_LABEL[status]}</Badge>
        <span className="text-xs text-muted-foreground">{items.length}</span>
      </div>
      <div className="flex flex-col gap-2">
        {items.length === 0 && <div className="empty-state py-6 text-sm">Nothing here.</div>}
        {items.map((item) => {
          const owner = item.assignees.find((a) => a.role === "owner");
          const ownerWip = status === "in_progress" && owner ? { count: wipCounts[owner.user_id] ?? 0, limit: wipLimit } : undefined;
          return <ItemCard canTransition={canTransition} item={item} key={item.id} ownerWip={ownerWip} workspaceId={workspaceId} />;
        })}
      </div>
    </div>
  );
}
