"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { ChevronDown, Lock } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { TransitionReasonDialog } from "@/components/workspace/items/transition-reason-dialog";
import { transitionItemAction } from "@/lib/workspace/items-actions";
import { ITEM_STATUS_LABEL, ITEM_STATUS_VARIANT, ITEM_TYPE_ICON, ITEM_PRIORITY_VARIANT, BUG_SEVERITY_VARIANT, TRANSITION_NEEDS_REASON } from "@/lib/workspace/items-constants";
import { ITEM_STATUS_NEXT, type ItemStatus, type WorkItem } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

interface ItemCardProps {
  workspaceId: string;
  item: WorkItem;
  canTransition: boolean;
  /** "n/limit" badge for this card's owner, shown only when set (in-progress column). */
  ownerWip?: { count: number; limit: number };
}

export function ItemCard({ workspaceId, item, canTransition, ownerWip }: ItemCardProps) {
  const [pending, startTransition] = useTransition();
  const [reasonTarget, setReasonTarget] = useState<ItemStatus | null>(null);
  const TypeIcon = ITEM_TYPE_ICON[item.type];
  const owner = item.assignees.find((a) => a.role === "owner");
  const targets = ITEM_STATUS_NEXT[item.status];

  function applyTransition(to: ItemStatus, reason?: string, blockerItemId?: string) {
    startTransition(async () => {
      const result = await transitionItemAction(workspaceId, item.id, { version: item.version, to, reason, blocker_item_id: blockerItemId });
      setReasonTarget(null);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success(`${item.key} moved to ${ITEM_STATUS_LABEL[to]}.`);
    });
  }

  function handleSelect(to: ItemStatus) {
    if (TRANSITION_NEEDS_REASON.has(to)) {
      setReasonTarget(to);
      return;
    }
    applyTransition(to);
  }

  return (
    <div className="card-base flex flex-col gap-2 p-4">
      <div className="flex items-start justify-between gap-2">
        <Link className="min-w-0 flex-1" href={ROUTES.workspaceItem(workspaceId, item.key)}>
          <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
            <TypeIcon aria-hidden className="h-3.5 w-3.5" />
            <span className="font-mono">{item.key}</span>
          </div>
          <p className="mt-1 truncate text-sm font-medium hover:text-primary">{item.title}</p>
        </Link>
      </div>

      <div className="flex flex-wrap items-center gap-1.5">
        <Badge variant={ITEM_PRIORITY_VARIANT[item.priority]}>{item.priority}</Badge>
        {item.severity && <Badge variant={BUG_SEVERITY_VARIANT[item.severity]}>{item.severity}</Badge>}
      </div>

      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
          {owner ? (
            <span className="truncate">{owner.name}</span>
          ) : (
            <span className="italic">Unassigned</span>
          )}
          {ownerWip && (
            <Badge className={ownerWip.count >= ownerWip.limit ? "text-destructive" : ""} variant="outline">
              {ownerWip.count}/{ownerWip.limit}
            </Badge>
          )}
        </div>

        {canTransition && targets.length > 0 && (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button className="h-7 gap-1 px-2" disabled={pending} size="sm" variant="outline">
                <Badge className="pointer-events-none" variant={ITEM_STATUS_VARIANT[item.status]}>
                  {ITEM_STATUS_LABEL[item.status]}
                </Badge>
                <ChevronDown aria-hidden className="h-3 w-3" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {targets.map((to) => (
                <DropdownMenuItem key={to} onSelect={() => handleSelect(to)}>
                  Move to {ITEM_STATUS_LABEL[to]}
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        )}
        {!canTransition && targets.length > 0 && (
          <Tooltip>
            <TooltipTrigger asChild>
              <span className="flex items-center gap-1 text-muted-foreground">
                <Lock aria-hidden className="h-3 w-3" />
                <Badge variant={ITEM_STATUS_VARIANT[item.status]}>{ITEM_STATUS_LABEL[item.status]}</Badge>
              </span>
            </TooltipTrigger>
            <TooltipContent>Open the item to see why this can&apos;t move from here.</TooltipContent>
          </Tooltip>
        )}
      </div>

      <TransitionReasonDialog
        open={reasonTarget !== null}
        pending={pending}
        to={reasonTarget}
        workspaceId={workspaceId}
        onConfirm={(reason, blockerItemId) => reasonTarget && applyTransition(reasonTarget, reason, blockerItemId)}
        onOpenChange={(open) => !open && setReasonTarget(null)}
      />
    </div>
  );
}
