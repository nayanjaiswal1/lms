"use client";

import * as React from "react";
import { useTransition } from "react";
import { RotateCw } from "lucide-react";
import { toast } from "sonner";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { apiFetch } from "@/lib/client/api";
import type { Invite } from "@/lib/orgs/types";
import { RevokeInviteButton } from "@/app/(app)/users/invite-list";
import { resendInviteAction } from "@/app/(app)/users/actions";

type InviteStatus = "pending" | "accepted" | "revoked" | "expired";

function inviteStatus(inv: Invite): InviteStatus {
  if (inv.accepted_at) return "accepted";
  if (inv.revoked_at) return "revoked";
  if (new Date(inv.expires_at) <= new Date()) return "expired";
  return "pending";
}

const STATUS_LABEL: Record<InviteStatus, string> = {
  pending:  "Pending",
  accepted: "Accepted",
  revoked:  "Revoked",
  expired:  "Expired",
};

function statusBadge(status: InviteStatus) {
  return (
    <Badge
      className={status === "accepted" ? "badge-success" : undefined}
      variant={status === "accepted" ? "outline" : status === "pending" ? "secondary" : "destructive"}
    >
      {STATUS_LABEL[status]}
    </Badge>
  );
}

interface ResendButtonProps {
  invite: Invite;
  orgId: string;
}

function ResendButton({ invite, orgId }: ResendButtonProps) {
  const [isPending, startTransition] = useTransition();

  function handleResend() {
    startTransition(async () => {
      const result = await resendInviteAction(orgId, invite.id);
      if (result.error) toast.error(result.error);
      else toast.success(`Invite resent to ${invite.email}.`);
    });
  }

  return (
    <Button
      aria-label={`Resend invite to ${invite.email}`}
      className="touch-target"
      disabled={isPending}
      size="icon"
      variant="ghost"
      onClick={handleResend}
    >
      <RotateCw aria-hidden className="h-4 w-4" />
    </Button>
  );
}

interface Props {
  orgId: string;
}

// Loaded on demand when the history view opens — every other status (pending
// invites) is already server-fetched for the page, but "all invites ever
// sent" is only useful here, so it isn't worth carrying on every page load.
export function InviteHistory({ orgId }: Props) {
  const [invites, setInvites] = React.useState<Invite[] | null>(null);

  React.useEffect(() => {
    void apiFetch<{ invites: Invite[] }>(`/orgs/${orgId}/invites?status=all&limit=100`).then(
      (res) => setInvites(res?.invites ?? []),
    );
  }, [orgId]);

  if (invites === null) {
    return (
      <div className="space-y-2">
        <Skeleton className="h-12 w-full" />
        <Skeleton className="h-12 w-full" />
        <Skeleton className="h-12 w-full" />
      </div>
    );
  }

  if (invites.length === 0) {
    return (
      <div className="empty-state py-8">
        <p className="text-sm text-muted-foreground">No invites have been sent yet.</p>
      </div>
    );
  }

  const sorted = [...invites].sort(
    (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
  );

  return (
    <div className="max-h-96 overflow-y-auto divide-y divide-border rounded-md border border-border">
      {sorted.map((invite) => {
        const status = inviteStatus(invite);
        return (
          <div className="flex items-center gap-3 px-3 py-2.5 text-sm" key={invite.id}>
            <div className="flex-1 min-w-0">
              <div className="font-medium text-foreground truncate">{invite.email}</div>
              <div className="text-xs text-muted-foreground">
                {invite.role} · {new Date(invite.created_at).toLocaleDateString()}
              </div>
            </div>
            {statusBadge(status)}
            {status === "pending" && (
              <div className="flex items-center gap-0.5 shrink-0">
                <ResendButton invite={invite} orgId={orgId} />
                <RevokeInviteButton iconOnly invite={invite} orgId={orgId} />
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
