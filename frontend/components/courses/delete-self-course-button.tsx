"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { deleteSelfCourseAction } from "@/app/(app)/courses/actions";
import ROUTES from "@/lib/routes";

interface DeleteSelfCourseButtonProps {
  courseId: string;
  courseTitle: string;
}

export function DeleteSelfCourseButton({ courseId, courseTitle }: DeleteSelfCourseButtonProps) {
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const router = useRouter();

  async function handleConfirm() {
    setPending(true);
    const result = await deleteSelfCourseAction(courseId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`Removed "${courseTitle}".`);
    router.push(ROUTES.DASHBOARD);
  }

  return (
    <>
      <Button
        className="text-destructive hover:text-destructive"
        size="sm"
        variant="ghost"
        onClick={() => setOpen(true)}
      >
        <Trash2 aria-hidden className="h-4 w-4" />
        Remove course
      </Button>
      <ConfirmDialog
        destructive
        confirmLabel="Remove"
        description="This permanently deletes this practice course and everything in it. This can't be undone."
        open={open}
        pending={pending}
        title={`Remove "${courseTitle}"?`}
        onConfirm={handleConfirm}
        onOpenChange={setOpen}
      />
    </>
  );
}
