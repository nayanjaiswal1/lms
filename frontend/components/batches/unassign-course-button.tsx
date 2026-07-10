"use client";

import * as React from "react";
import { X } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { unassignCourseAction } from "@/lib/batches/actions";

interface UnassignCourseButtonProps {
  batchId: string;
  courseId: string;
  courseTitle: string;
}

export function UnassignCourseButton({ batchId, courseId, courseTitle }: UnassignCourseButtonProps) {
  const [pending, setPending] = React.useState(false);
  const router = useRouter();

  async function handleUnassign() {
    setPending(true);
    const result = await unassignCourseAction(batchId, courseId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`${courseTitle} unassigned from batch.`);
    router.refresh();
  }

  return (
    <Button
      aria-label={`Unassign ${courseTitle} from batch`}
      disabled={pending}
      size="icon"
      variant="ghost"
      onClick={handleUnassign}
    >
      <X aria-hidden className="h-4 w-4 text-destructive" />
    </Button>
  );
}
