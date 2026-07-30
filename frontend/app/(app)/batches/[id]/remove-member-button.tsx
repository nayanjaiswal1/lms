"use client";

import * as React from "react";
import { Trash2 } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { removeBatchMemberAction } from "@/app/(app)/batches/actions";

interface RemoveMemberButtonProps {
  batchId: string;
  userId: string;
  userName: string;
}

export function RemoveMemberButton({ batchId, userId, userName }: RemoveMemberButtonProps) {
  const [pending, setPending] = React.useState(false);
  const [confirmOpen, setConfirmOpen] = React.useState(false);
  const router = useRouter();

  async function handleRemove() {
    setPending(true);
    const result = await removeBatchMemberAction(batchId, userId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`${userName} removed from batch.`);
    router.refresh();
  }

  return (
    <>
      <Button
        aria-label={`Remove ${userName} from batch`}
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
        description={`${userName} will lose access to this batch's content and progress tracking.`}
        open={confirmOpen}
        pending={pending}
        title={`Remove ${userName} from batch?`}
        onConfirm={handleRemove}
        onOpenChange={setConfirmOpen}
      />
    </>
  );
}
