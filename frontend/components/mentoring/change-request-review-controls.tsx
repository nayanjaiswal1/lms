"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { approveChangeRequestAction, denyChangeRequestAction } from "@/lib/mentoring/actions";

interface ChangeRequestReviewControlsProps {
  requestId: string;
}

export function ChangeRequestReviewControls({ requestId }: ChangeRequestReviewControlsProps) {
  const [pending, setPending] = useState<"approve" | "deny" | null>(null);
  const router = useRouter();

  async function handle(action: "approve" | "deny") {
    setPending(action);
    const result =
      action === "approve"
        ? await approveChangeRequestAction(requestId)
        : await denyChangeRequestAction(requestId);
    setPending(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(action === "approve" ? "Request approved — ticket reopened." : "Request denied.");
    router.refresh();
  }

  return (
    <div className="flex items-center gap-2">
      <Button disabled={pending !== null} size="sm" onClick={() => void handle("approve")}>
        {pending === "approve" ? "Approving…" : "Approve"}
      </Button>
      <Button
        disabled={pending !== null}
        size="sm"
        variant="outline"
        onClick={() => void handle("deny")}
      >
        {pending === "deny" ? "Denying…" : "Deny"}
      </Button>
    </div>
  );
}
