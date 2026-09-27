"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Archive, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { archiveWorkItemAction, deleteWorkItemAction } from "@/lib/workspace/items-actions";
import type { ItemDetail } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

interface ItemDangerActionsProps {
  workspaceId: string;
  item: ItemDetail;
}

/** Delete only when can_delete (todo, single create event, creator/manager+);
 * everything else falls back to Archive (contract-phase2.md "Delete"/"Archive"). */
export function ItemDangerActions({ workspaceId, item }: ItemDangerActionsProps) {
  const router = useRouter();
  const [confirming, setConfirming] = useState(false);
  const [pending, startTransition] = useTransition();

  if (!item.can_delete && !item.can_edit) return null;

  function run() {
    startTransition(async () => {
      const result = item.can_delete
        ? await deleteWorkItemAction(workspaceId, item.id)
        : await archiveWorkItemAction(workspaceId, item.id);
      setConfirming(false);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success(item.can_delete ? "Item deleted." : "Item archived.");
      router.push(ROUTES.workspaceBoard(workspaceId));
    });
  }

  return (
    <>
      <Button className="gap-1.5 text-destructive hover:text-destructive" size="sm" variant="ghost" onClick={() => setConfirming(true)}>
        {item.can_delete ? <Trash2 aria-hidden className="h-4 w-4" /> : <Archive aria-hidden className="h-4 w-4" />}
        {item.can_delete ? "Delete" : "Archive"}
      </Button>
      <ConfirmDialog
        destructive
        confirmLabel={item.can_delete ? "Delete" : "Archive"}
        description={
          item.can_delete
            ? `${item.key} will be permanently deleted. This can't be undone.`
            : `${item.key} will be archived and hidden from the board and list.`
        }
        open={confirming}
        pending={pending}
        title={item.can_delete ? "Delete item?" : "Archive item?"}
        onConfirm={run}
        onOpenChange={setConfirming}
      />
    </>
  );
}
