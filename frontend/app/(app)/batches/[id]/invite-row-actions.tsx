"use client";

import * as React from "react";
import { RotateCw, X } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { resendBatchInvitationAction, revokeBatchInvitationAction } from "@/app/(app)/batches/actions";

interface InviteRowActionsProps {
  batchId: string;
  invitationId: string;
  email: string;
}

export function InviteRowActions({ batchId, invitationId, email }: InviteRowActionsProps) {
  const [pending, setPending] = React.useState(false);
  const router = useRouter();

  async function handleResend() {
    setPending(true);
    const result = await resendBatchInvitationAction(batchId, invitationId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`Invite resent to ${email}.`);
    router.refresh();
  }

  async function handleRevoke() {
    setPending(true);
    const result = await revokeBatchInvitationAction(batchId, invitationId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`Invite to ${email} revoked.`);
    router.refresh();
  }

  return (
    <div className="flex justify-end gap-1">
      <Button
        aria-label={`Resend invite to ${email}`}
        className="touch-target"
        disabled={pending}
        size="icon"
        variant="ghost"
        onClick={handleResend}
      >
        <RotateCw aria-hidden className="h-4 w-4" />
      </Button>
      <Button
        aria-label={`Revoke invite to ${email}`}
        className="touch-target"
        disabled={pending}
        size="icon"
        variant="ghost"
        onClick={handleRevoke}
      >
        <X aria-hidden className="h-4 w-4 text-destructive" />
      </Button>
    </div>
  );
}
