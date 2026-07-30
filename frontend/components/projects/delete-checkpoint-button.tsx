"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Trash2 } from "lucide-react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { deleteCheckpointAction } from "@/app/(app)/projects/actions";

interface DeleteCheckpointButtonProps {
  checkpointId: string;
  assignmentId: string;
  title: string;
}

export function DeleteCheckpointButton({ checkpointId, assignmentId, title }: DeleteCheckpointButtonProps) {
  const [pending, setPending] = React.useState(false);
  const [confirmOpen, setConfirmOpen] = React.useState(false);
  const router = useRouter();

  async function handleDelete() {
    setPending(true);
    const result = await deleteCheckpointAction(checkpointId, assignmentId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Checkpoint deleted.");
    router.refresh();
  }

  return (
    <>
      <Button aria-label={`Delete ${title}`} disabled={pending} size="icon" variant="ghost" onClick={() => setConfirmOpen(true)}>
        <Trash2 aria-hidden className="h-4 w-4 text-destructive" />
      </Button>
      <ConfirmDialog
        destructive
        confirmLabel="Delete"
        description={`This permanently deletes the "${title}" checkpoint and every team's progress on it.`}
        open={confirmOpen}
        pending={pending}
        title="Delete checkpoint?"
        onConfirm={handleDelete}
        onOpenChange={setConfirmOpen}
      />
    </>
  );
}
