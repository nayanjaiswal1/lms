"use client";

import * as React from "react";
import { Rocket } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { publishAssignmentAction } from "@/app/(app)/projects/actions";

interface PublishAssignmentButtonProps {
  assignmentId: string;
}

export function PublishAssignmentButton({ assignmentId }: PublishAssignmentButtonProps) {
  const [pending, setPending] = React.useState(false);
  const router = useRouter();

  async function handlePublish() {
    setPending(true);
    const result = await publishAssignmentAction(assignmentId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Assignment published — teams are provisioning.");
    router.refresh();
  }

  return (
    <Button disabled={pending} onClick={handlePublish}>
      <Rocket aria-hidden className="mr-1.5 h-4 w-4" />
      {pending ? "Publishing…" : "Publish"}
    </Button>
  );
}
