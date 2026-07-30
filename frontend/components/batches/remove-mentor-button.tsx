"use client";

import * as React from "react";
import { Trash2 } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { removeBatchMentorAction } from "@/lib/batches/actions";

interface RemoveMentorButtonProps {
  batchId: string;
  userId: string;
  userName: string;
}

export function RemoveMentorButton({ batchId, userId, userName }: RemoveMentorButtonProps) {
  const [pending, setPending] = React.useState(false);
  const [confirmOpen, setConfirmOpen] = React.useState(false);
  const router = useRouter();

  async function handleRemove() {
    setPending(true);
    const result = await removeBatchMentorAction(batchId, userId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`${userName} removed as mentor.`);
    router.refresh();
  }

  return (
    <>
      <Button
        aria-label={`Remove ${userName} as mentor`}
        disabled={pending}
        size="icon"
        variant="ghost"
        onClick={() => setConfirmOpen(true)}
      >
        <Trash2 aria-hidden className="h-4 w-4 text-destructive" />
      </Button>
      <ConfirmDialog
        destructive
        confirmLabel="Remove"
        description={`${userName} will be unassigned as mentor for this batch.`}
        open={confirmOpen}
        pending={pending}
        title={`Remove ${userName} as mentor?`}
        onConfirm={handleRemove}
        onOpenChange={setConfirmOpen}
      />
    </>
  );
}
