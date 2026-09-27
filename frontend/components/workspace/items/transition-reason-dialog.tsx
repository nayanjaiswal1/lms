"use client";

import { useState } from "react";

import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Textarea } from "@/components/ui/textarea";
import { ItemSearchPicker } from "@/components/workspace/items/item-search-picker";
import { ITEM_STATUS_LABEL } from "@/lib/workspace/items-constants";
import type { ItemStatus, WorkItem } from "@/lib/workspace/types";

interface TransitionReasonDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  to: ItemStatus | null;
  pending: boolean;
  workspaceId: string;
  /** Exclude this item itself from the blocker picker. */
  excludeItemId?: string;
  onConfirm: (reason: string, blockerItemId?: string) => void;
}

/** Collects the reason (blocked/wont_do/reopened) and, for `blocked`, the
 * blocking item — statemachine.go requires both before the transition call. */
export function TransitionReasonDialog({ open, onOpenChange, to, pending, workspaceId, excludeItemId, onConfirm }: TransitionReasonDialogProps) {
  const [reason, setReason] = useState("");
  const [blocker, setBlocker] = useState<WorkItem | null>(null);

  const needsBlocker = to === "blocked";
  const canConfirm = reason.trim().length > 0 && (!needsBlocker || blocker !== null);

  function reset() {
    setReason("");
    setBlocker(null);
  }

  return (
    <AlertDialog open={open} onOpenChange={(next) => { if (!next) reset(); onOpenChange(next); }}>
      <AlertDialogContent className="modal-responsive">
        <AlertDialogHeader>
          <AlertDialogTitle>{to ? `Move to ${ITEM_STATUS_LABEL[to]}` : "Move item"}</AlertDialogTitle>
          <AlertDialogDescription>A reason is required for this transition.</AlertDialogDescription>
        </AlertDialogHeader>

        <Textarea
          aria-label="Reason"
          placeholder="Why is this changing status?"
          rows={3}
          value={reason}
          onChange={(e) => setReason(e.target.value)}
        />

        {needsBlocker && (
          <ItemSearchPicker
            excludeItemId={excludeItemId}
            placeholder="Search for the blocking item…"
            value={blocker}
            workspaceId={workspaceId}
            onChange={setBlocker}
          />
        )}

        <AlertDialogFooter>
          <AlertDialogCancel disabled={pending}>Cancel</AlertDialogCancel>
          <AlertDialogAction
            disabled={pending || !canConfirm}
            onClick={() => onConfirm(reason.trim(), blocker?.id)}
          >
            {pending ? "Moving…" : "Confirm"}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
