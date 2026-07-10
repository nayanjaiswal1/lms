"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { MailCheck, MailX, Clock, RotateCw, Ban } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { resendInvitationAction, revokeInvitationAction } from "@/lib/batches/actions";

interface Invitation {
  id: string;
  email: string;
  accepted_at: string | null;
  declined_at: string | null;
  expires_at: string;
  invited_at: string;
}

interface InvitationListProps {
  batchId: string;
  invitations: Invitation[];
}

function statusLabel(inv: Invitation): { label: string; className: string; Icon: React.ComponentType<{ className?: string }> } {
  if (inv.accepted_at) return { label: "Accepted", className: "text-primary", Icon: MailCheck };
  if (inv.declined_at) return { label: "Declined", className: "text-destructive", Icon: MailX };
  if (new Date(inv.expires_at) < new Date()) return { label: "Expired", className: "text-muted-foreground", Icon: Clock };
  return { label: "Pending", className: "text-muted-foreground", Icon: Clock };
}

export function InvitationList({ batchId, invitations }: InvitationListProps) {
  const [pendingId, setPendingId] = React.useState<string | null>(null);
  const router = useRouter();

  if (invitations.length === 0) {
    return <p className="text-sm text-muted-foreground">No invitations sent yet.</p>;
  }

  async function handleResend(invId: string, email: string) {
    setPendingId(invId);
    const result = await resendInvitationAction(batchId, invId);
    setPendingId(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`Invitation resent to ${email}.`);
    router.refresh();
  }

  async function handleRevoke(invId: string, email: string) {
    setPendingId(invId);
    const result = await revokeInvitationAction(batchId, invId);
    setPendingId(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`Invitation to ${email} revoked.`);
    router.refresh();
  }

  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-xs text-muted-foreground">
            <th className="pb-2 font-medium">Email</th>
            <th className="pb-2 font-medium">Status</th>
            <th className="pb-2 font-medium">Sent</th>
            <th className="pb-2 font-medium">Expires</th>
            <th className="pb-2 font-medium sr-only">Actions</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {invitations.map((inv) => {
            const { label, className, Icon } = statusLabel(inv);
            const isPending = pendingId === inv.id;
            const canRevoke = !inv.accepted_at && !inv.declined_at;
            return (
              <tr className="text-sm" key={inv.id}>
                <td className="py-2.5 pr-4 font-mono text-sm">{inv.email}</td>
                <td className="py-2.5 pr-4">
                  <span className={cn("flex items-center gap-1", className)}>
                    <Icon className="h-3.5 w-3.5" />
                    {label}
                  </span>
                </td>
                <td className="py-2.5 pr-4 text-muted-foreground">
                  {new Date(inv.invited_at).toLocaleDateString()}
                </td>
                <td className="py-2.5 pr-4 text-muted-foreground">
                  {new Date(inv.expires_at).toLocaleDateString()}
                </td>
                <td className="py-2.5 text-right">
                  {canRevoke && (
                    <div className="flex justify-end gap-1">
                      <Button
                        disabled={isPending}
                        size="sm"
                        variant="ghost"
                        onClick={() => handleResend(inv.id, inv.email)}
                      >
                        <RotateCw aria-hidden className="mr-1 h-3.5 w-3.5" />
                        Resend
                      </Button>
                      <Button
                        disabled={isPending}
                        size="sm"
                        variant="ghost"
                        onClick={() => handleRevoke(inv.id, inv.email)}
                      >
                        <Ban aria-hidden className="mr-1 h-3.5 w-3.5 text-destructive" />
                        Revoke
                      </Button>
                    </div>
                  )}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
