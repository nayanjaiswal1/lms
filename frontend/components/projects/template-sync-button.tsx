"use client";

import * as React from "react";
import { UploadCloud } from "lucide-react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { runTemplateSyncAction } from "@/app/(app)/projects/actions";

interface TemplateSyncButtonProps {
  assignmentId: string;
}

// Fire-and-confirm trigger for gitlab.template_sync — opens one cross-fork
// merge request per team's fork in the background (see
// service_template.go's RunTemplateSync). No live result view: the MRs land
// directly on each team's own GitLab project, there's nothing on this page
// to reflect back.
export function TemplateSyncButton({ assignmentId }: TemplateSyncButtonProps) {
  const [pending, setPending] = React.useState(false);

  async function handleSync() {
    setPending(true);
    const result = await runTemplateSyncAction(assignmentId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Template sync started — merge requests will appear on each team's project.");
  }

  return (
    <Button disabled={pending} variant="outline" onClick={() => void handleSync()}>
      <UploadCloud aria-hidden className="mr-1.5 h-4 w-4" />
      {pending ? "Starting…" : "Sync template update"}
    </Button>
  );
}
