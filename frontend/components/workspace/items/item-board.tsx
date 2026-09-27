"use client";

import { parseAsStringEnum, useQueryState } from "nuqs";

import { Button } from "@/components/ui/button";
import { ItemBoardColumn } from "@/components/workspace/items/item-board-column";
import { useProjectRole } from "@/components/workspace/project-role-provider";
import { BOARD_STATUSES, ITEM_STATUS_LABEL } from "@/lib/workspace/items-constants";
import type { ItemStatus, WorkItem } from "@/lib/workspace/types";

interface ItemBoardProps {
  workspaceId: string;
  items: WorkItem[];
  wipLimit: number;
}

/** "Backlog board" (never bare "board" — see 04-frontend.md §1 naming collision
 * with the marketplace board). Mobile: one column + segment control. Desktop:
 * all columns side by side (no drag — status changes go through the card's menu
 * either way, so drag would just be a second path to the same call). */
export function ItemBoard({ workspaceId, items, wipLimit }: ItemBoardProps) {
  const { atLeast } = useProjectRole();
  const canTransition = atLeast("member");
  const [mobileColumn, setMobileColumn] = useQueryState("column", parseAsStringEnum<ItemStatus>(BOARD_STATUSES).withDefault("todo"));

  const wipCounts: Record<string, number> = {};
  for (const item of items) {
    if (item.status !== "in_progress") continue;
    const owner = item.assignees.find((a) => a.role === "owner");
    if (!owner) continue;
    wipCounts[owner.user_id] = (wipCounts[owner.user_id] ?? 0) + 1;
  }

  const byStatus: Record<ItemStatus, WorkItem[]> = Object.fromEntries(
    BOARD_STATUSES.map((s) => [s, items.filter((i) => i.status === s)]),
  ) as Record<ItemStatus, WorkItem[]>;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex gap-1.5 overflow-x-auto lg:hidden">
        {BOARD_STATUSES.map((s) => (
          <Button
            className="shrink-0"
            key={s}
            size="sm"
            variant={mobileColumn === s ? "default" : "outline"}
            onClick={() => void setMobileColumn(s)}
          >
            {ITEM_STATUS_LABEL[s]} ({byStatus[s].length})
          </Button>
        ))}
      </div>

      <div className="lg:hidden">
        <ItemBoardColumn
          canTransition={canTransition}
          items={byStatus[mobileColumn]}
          status={mobileColumn}
          wipCounts={wipCounts}
          wipLimit={wipLimit}
          workspaceId={workspaceId}
        />
      </div>

      <div className="hidden gap-4 lg:grid lg:grid-cols-7">
        {BOARD_STATUSES.map((s) => (
          <ItemBoardColumn
            canTransition={canTransition}
            items={byStatus[s]}
            key={s}
            status={s}
            wipCounts={wipCounts}
            wipLimit={wipLimit}
            workspaceId={workspaceId}
          />
        ))}
      </div>
    </div>
  );
}
