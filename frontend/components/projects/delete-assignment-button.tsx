"use client";

import * as React from "react";
import { Trash2 } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { deleteAssignmentAction } from "@/app/(app)/projects/actions";
import ROUTES from "@/lib/routes";

interface DeleteAssignmentButtonProps {
  assignmentId: string;
}

export function DeleteAssignmentButton({ assignmentId }: DeleteAssignmentButtonProps) {
  const [pending, setPending] = React.useState(false);
  const [confirmOpen, setConfirmOpen] = React.useState(false);
  const router = useRouter();

  async function handleDelete() {
    setPending(true);
    const result = await deleteAssignmentAction(assignmentId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Assignment deleted.");
    router.push(ROUTES.PROJECTS);
  }

  return (
    <>
      <Button disabled={pending} variant="outline" onClick={() => setConfirmOpen(true)}>
        <Trash2 aria-hidden className="mr-1.5 h-4 w-4 text-destructive" />
        Delete
      </Button>
      <ConfirmDialog
        destructive
        confirmLabel="Delete"
        description="This permanently deletes the assignment, its checkpoints, and every team's progress on it. This can't be undone."
        open={confirmOpen}
        pending={pending}
        title="Delete assignment?"
        onConfirm={handleDelete}
        onOpenChange={setConfirmOpen}
      />
    </>
  );
}
