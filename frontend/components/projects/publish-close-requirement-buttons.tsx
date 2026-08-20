"use client";

import * as React from "react";
import { Ban, Rocket } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { closeRequirementAction, publishRequirementAction } from "@/app/(app)/projects/actions";
import type { RequirementStatus } from "@/lib/projects/types";

interface PublishCloseRequirementButtonsProps {
  requirementId: string;
  status: RequirementStatus;
}

export function PublishCloseRequirementButtons({ requirementId, status }: PublishCloseRequirementButtonsProps) {
  const [pending, setPending] = React.useState(false);
  const router = useRouter();

  async function handlePublish() {
    setPending(true);
    const result = await publishRequirementAction(requirementId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Requirement published — it's now open on the board.");
    router.refresh();
  }

  async function handleClose() {
    setPending(true);
    const result = await closeRequirementAction(requirementId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Requirement closed to new applications.");
    router.refresh();
  }

  if (status === "draft") {
    return (
      <Button disabled={pending} onClick={handlePublish}>
        <Rocket aria-hidden className="mr-1.5 h-4 w-4" />
        {pending ? "Publishing…" : "Publish"}
      </Button>
    );
  }

  if (status === "open") {
    return (
      <Button disabled={pending} variant="outline" onClick={handleClose}>
        <Ban aria-hidden className="mr-1.5 h-4 w-4" />
        {pending ? "Closing…" : "Close applications"}
      </Button>
    );
  }

  return null;
}
