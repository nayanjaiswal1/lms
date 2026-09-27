"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";

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
import { Button } from "@/components/ui/button";
import { acceptInterestAction } from "@/lib/workspace/actions";
import type { Interest } from "@/lib/workspace/types";

interface AcceptInterestDialogProps {
  workspaceId: string;
  interest: Interest;
  seatsUsed: number;
  teamSizeMax: number;
  onAccepted: () => void;
}

/** Seat check + confirmation before accepting an interest. Whether the email
 * belongs to an existing MindForge account never surfaces here — the outcome
 * toast is always "Invitation sent" (see D14 / 02 §4.4: no membership oracle). */
export function AcceptInterestDialog({ workspaceId, interest, seatsUsed, teamSizeMax, onAccepted }: AcceptInterestDialogProps) {
  const [open, setOpen] = useState(false);
  const [pending, startTransition] = useTransition();
  const seatsFull = seatsUsed >= teamSizeMax;

  function handleConfirm() {
    startTransition(async () => {
      const result = await acceptInterestAction(workspaceId, interest.id);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      setOpen(false);
      toast.success("Invitation sent.");
      onAccepted();
    });
  }

  return (
    <AlertDialog open={open} onOpenChange={setOpen}>
      <Button disabled={interest.status !== "new"} size="sm" onClick={() => setOpen(true)}>
        Accept
      </Button>
      <AlertDialogContent className="modal-responsive">
        <AlertDialogHeader>
          <AlertDialogTitle>Accept {interest.name}&apos;s interest?</AlertDialogTitle>
          <AlertDialogDescription>
            {seatsFull
              ? "Seats are full — raise the team size limit first."
              : `An invite will be sent to ${interest.email}. Seats used: ${seatsUsed} of ${teamSizeMax}.`}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel disabled={pending}>Cancel</AlertDialogCancel>
          <AlertDialogAction disabled={pending || seatsFull} onClick={handleConfirm}>
            {pending ? "Accepting…" : "Accept"}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
