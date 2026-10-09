"use client";

import * as React from "react";
import { Rocket } from "lucide-react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { publishCohortAction } from "@/lib/workspace/cohort-actions";

interface PublishAssignmentButtonProps {
  assignmentId: string;
}

export function PublishAssignmentButton({ assignmentId }: PublishAssignmentButtonProps) {
  const [pending, setPending] = React.useState(false);

  async function handlePublish() {
    setPending(true);
    const result = await publishCohortAction(assignmentId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Assignment published — teams are provisioning.");
  }

  return (
    <Button disabled={pending} onClick={handlePublish}>
      <Rocket aria-hidden className="mr-1.5 h-4 w-4" />
      {pending ? "Publishing…" : "Publish"}
    </Button>
  );
}
