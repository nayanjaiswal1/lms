"use client";

import { useActionState } from "react";
import { X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { Invite } from "@/lib/orgs/types";
import { revokeInviteAction, type MemberActionState } from "@/app/(app)/users/actions";

interface InviteRowProps {
  invite: Invite;
  orgId: string;
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

interface RevokeInviteButtonProps {
  invite: Invite;
  orgId: string;
  /** Compact icon variant for the denser invite-history list. */
  iconOnly?: boolean;
}

// Shared by the pending list below and invite-history.tsx — one revoke
// endpoint, two densities.
export function RevokeInviteButton({ invite, orgId, iconOnly }: RevokeInviteButtonProps) {
  const [state, action, isPending] = useActionState<MemberActionState, FormData>(
    revokeInviteAction,
    {},
  );

  return (
    <form action={action}>
      <input type="hidden" name="org_id" value={orgId} />
      <input type="hidden" name="invite_id" value={invite.id} />
      <Button
        aria-label={`Revoke invite for ${invite.email}`}
        className={iconOnly ? "touch-target" : undefined}
        disabled={isPending}
        size={iconOnly ? "icon" : "sm"}
        type="submit"
        variant={iconOnly ? "ghost" : "destructive"}
      >
        {iconOnly ? <X aria-hidden className="h-4 w-4 text-destructive" /> : "Revoke"}
      </Button>
      {state.error && (
        <p className="text-xs text-destructive" role="alert">{state.error}</p>
      )}
    </form>
  );
}

function InviteRow({ invite, orgId }: InviteRowProps) {
  const isExpired = new Date(invite.expires_at) < new Date();

  return (
    <div className="flex flex-col sm:flex-row sm:items-center gap-3 py-3 border-b border-border last:border-0">
      <div className="flex-1 min-w-0">
        <div className="text-sm font-medium text-foreground truncate">{invite.email}</div>
        <div className="text-xs text-muted-foreground">
          Role: {invite.role} · Expires {formatDate(invite.expires_at)}
        </div>
      </div>

      <div className="flex items-center gap-2 flex-wrap">
        <Badge variant={isExpired ? "destructive" : "secondary"}>
          {isExpired ? "Expired" : "Pending"}
        </Badge>
        <Badge variant="outline">{invite.role}</Badge>
      </div>

      <RevokeInviteButton invite={invite} orgId={orgId} />
    </div>
  );
}

interface InviteListProps {
  invites: Invite[];
  orgId: string;
}

export function InviteList({ invites, orgId }: InviteListProps) {
  const pending = invites.filter((inv) => inv.accepted_at === null && inv.revoked_at === null);

  if (pending.length === 0) {
    return (
      <div className="empty-state py-8">
        <p className="text-sm text-muted-foreground">No pending invites.</p>
      </div>
    );
  }

  return (
    <div>
      {pending.map((invite) => (
        <InviteRow key={invite.id} invite={invite} orgId={orgId} />
      ))}
    </div>
  );
}
