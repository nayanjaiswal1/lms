"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { DropdownMenuItem } from "@/components/ui/dropdown-menu";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { deleteSelfCourseModuleAction } from "@/app/(app)/courses/actions";
import ROUTES from "@/lib/routes";

interface DeleteSelfCourseModuleButtonProps {
  courseSlug: string;
  moduleId: string;
  moduleTitle: string;
  fallbackModuleId: string | null;
  /** Renders as a DropdownMenuItem instead of a standalone Button — for use inside LessonMoreMenu. */
  asMenuItem?: boolean;
}

export function DeleteSelfCourseModuleButton({
  courseSlug,
  moduleId,
  moduleTitle,
  fallbackModuleId,
  asMenuItem = false,
}: DeleteSelfCourseModuleButtonProps) {
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const router = useRouter();

  async function handleConfirm() {
    setPending(true);
    const result = await deleteSelfCourseModuleAction(courseSlug, moduleId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`Removed "${moduleTitle}".`);
    router.push(
      fallbackModuleId ? ROUTES.courseLearnModule(courseSlug, fallbackModuleId) : ROUTES.courseLearn(courseSlug),
    );
  }

  const label = (
    <>
      <Trash2 aria-hidden className="h-4 w-4" />
      Delete lesson
    </>
  );

  return (
    <>
      {asMenuItem ? (
        <DropdownMenuItem
          className="text-destructive focus:text-destructive"
          onSelect={() => setOpen(true)}
        >
          {label}
        </DropdownMenuItem>
      ) : (
        <Button
          aria-label="Delete lesson"
          className="text-destructive hover:text-destructive"
          size="sm"
          variant="ghost"
          onClick={() => setOpen(true)}
        >
          {label}
        </Button>
      )}
      <ConfirmDialog
        destructive
        confirmLabel="Delete"
        description="This permanently deletes this lesson from your practice course. This can't be undone."
        open={open}
        pending={pending}
        title={`Delete "${moduleTitle}"?`}
        onConfirm={handleConfirm}
        onOpenChange={setOpen}
      />
    </>
  );
}
