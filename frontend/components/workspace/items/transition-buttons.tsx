"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Lock } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { ConflictDialog } from "@/components/workspace/items/conflict-dialog";
import { TransitionReasonDialog } from "@/components/workspace/items/transition-reason-dialog";
import { useProjectRole } from "@/components/workspace/project-role-provider";
import { transitionItemAction } from "@/lib/workspace/items-actions";
import { ITEM_STATUS_LABEL, TRANSITION_NEEDS_REASON } from "@/lib/workspace/items-constants";
import type { ItemDetail, ItemStatus, WorkItem } from "@/lib/workspace/types";

interface TransitionButtonsProps {
  workspaceId: string;
  item: ItemDetail;
}

/** Right rail status control — the only place items actually move on the
 * detail page (the header shows status as a read-only badge). Only
 * `legal_transitions`/`locked_transitions` from the server are trusted here;
 * the static ITEM_STATUS_NEXT map is for the board, which has no per-item
 * server-computed set to work from. */
export function TransitionButtons({ workspaceId, item }: TransitionButtonsProps) {
  const router = useRouter();
  const { atLeast } = useProjectRole();
  const [pending, startTransition] = useTransition();
  const [reasonTarget, setReasonTarget] = useState<ItemStatus | null>(null);
  const [conflict, setConflict] = useState<WorkItem | null>(null);
  const [lastAttempt, setLastAttempt] = useState<{ to: ItemStatus; reason?: string; blockerItemId?: string } | null>(null);
  const lockedEntries = Object.entries(item.locked_transitions) as [ItemStatus, string][];

  function applyTransition(to: ItemStatus, reason?: string, blockerItemId?: string, version = item.version) {
    setLastAttempt({ to, reason, blockerItemId });
    startTransition(async () => {
      const result = await transitionItemAction(workspaceId, item.id, { version, to, reason, blocker_item_id: blockerItemId });
      setReasonTarget(null);
      if (result.conflict) {
        setConflict(result.conflict);
        return;
      }
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success(`Moved to ${ITEM_STATUS_LABEL[to]}.`);
      router.refresh();
    });
  }

  function handleClick(to: ItemStatus) {
    if (TRANSITION_NEEDS_REASON.has(to)) {
      setReasonTarget(to);
      return;
    }
    applyTransition(to);
  }

  if (item.legal_transitions.length === 0 && lockedEntries.length === 0) return null;

  return (
    <div className="flex flex-col gap-2">
      <h2 className="text-sm font-medium text-muted-foreground">Status</h2>
      <div className="flex flex-wrap gap-2">
        {item.legal_transitions.map((to) => (
          <Button disabled={pending} key={to} size="sm" variant="outline" onClick={() => handleClick(to)}>
            {ITEM_STATUS_LABEL[to]}
          </Button>
        ))}
        {lockedEntries.map(([to, reason]) => (
          <Tooltip key={to}>
            <TooltipTrigger asChild>
              <span>
                <Button disabled className="gap-1.5" size="sm" variant="outline">
                  <Lock aria-hidden className="h-3.5 w-3.5" />
                  {ITEM_STATUS_LABEL[to]}
                </Button>
              </span>
            </TooltipTrigger>
            <TooltipContent>{reason}</TooltipContent>
          </Tooltip>
        ))}
      </div>

      <TransitionReasonDialog
        excludeItemId={item.id}
        open={reasonTarget !== null}
        pending={pending}
        to={reasonTarget}
        workspaceId={workspaceId}
        onConfirm={(reason, blockerItemId) => reasonTarget && applyTransition(reasonTarget, reason, blockerItemId)}
        onOpenChange={(open) => !open && setReasonTarget(null)}
      />

      <ConflictDialog
        canOverwrite={atLeast("manager")}
        current={conflict}
        fields={[{ label: "Status", yours: lastAttempt?.to ?? "", current: conflict?.status ?? "" }]}
        open={conflict !== null}
        pending={pending}
        onOpenChange={(o) => !o && setConflict(null)}
        onOverwrite={(version) => lastAttempt && applyTransition(lastAttempt.to, lastAttempt.reason, lastAttempt.blockerItemId, version)}
        onReload={() => { setConflict(null); router.refresh(); }}
      />
    </div>
  );
}
