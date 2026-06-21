"use client";

import { useActionState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { Invite } from "@/lib/orgs/types";
import { revokeInviteAction, type MemberActionState } from "@/app/org/settings/members/actions";

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

function InviteRow({ invite, orgId }: InviteRowProps) {
  const [state, action, isPending] = useActionState<MemberActionState, FormData>(
    revokeInviteAction,
    {},
  );

  const isExpired = new Date(invite.expires_at) < new Date();

  return (
    <div className="flex flex-col sm:flex-row sm:items-center gap-3 py-3 border-b border-border last:border-0">
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-foreground truncate">{invite.email}</p>
        <p className="text-xs text-muted-foreground">
          Role: {invite.role} · Expires {formatDate(invite.expires_at)}
        </p>
      </div>

      <div className="flex items-center gap-2 flex-wrap">
        <Badge variant={isExpired ? "destructive" : "secondary"}>
          {isExpired ? "Expired" : "Pending"}
        </Badge>
        <Badge variant="outline">{invite.role}</Badge>
      </div>

      <form action={action}>
        <input type="hidden" name="org_id" value={orgId} />
        <input type="hidden" name="invite_id" value={invite.id} />
        <Button
          aria-label={`Revoke invite for ${invite.email}`}
          disabled={isPending}
          size="sm"
          type="submit"
          variant="destructive"
        >
          Revoke
        </Button>
      </form>

      {state.error && (
        <p className="text-xs text-destructive w-full" role="alert">{state.error}</p>
      )}
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
