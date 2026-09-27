"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Check, X } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { respondToWorkspaceInviteAction } from "@/lib/workspace/actions";
import type { ProjectSummary } from "@/lib/workspace/types";

interface InvitationListProps {
  invitations: ProjectSummary[];
}

/** Pending "someone added you as a member" invites — distinct from the
 * public share-link interest flow (that goes through /join/[token]). */
export function InvitationList({ invitations }: InvitationListProps) {
  const [items, setItems] = useState(invitations);
  const [pendingId, setPendingId] = useState<string | null>(null);

  async function respond(workspaceId: string, accept: boolean) {
    setPendingId(workspaceId);
    const result = await respondToWorkspaceInviteAction(workspaceId, accept);
    setPendingId(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(accept ? "Joined the workspace." : "Invitation declined.");
    setItems((prev) => prev.filter((i) => i.id !== workspaceId));
  }

  if (items.length === 0) return null;

  return (
    <div className="card-base flex flex-col gap-3">
      <h2 className="subsection-title">Pending invitations</h2>
      <ul className="flex flex-col gap-2">
        {items.map((invite) => (
          <li className="flex items-center justify-between gap-2" key={invite.id}>
            <div className="min-w-0">
              <p className="truncate font-medium">{invite.title}</p>
              <Badge variant="outline">{invite.key_prefix}</Badge>
            </div>
            <div className="flex gap-2">
              <Button
                aria-label="Accept invitation"
                disabled={pendingId === invite.id}
                size="icon"
                variant="outline"
                onClick={() => respond(invite.id, true)}
              >
                <Check aria-hidden className="h-4 w-4" />
              </Button>
              <Button
                aria-label="Decline invitation"
                disabled={pendingId === invite.id}
                size="icon"
                variant="ghost"
                onClick={() => respond(invite.id, false)}
              >
                <X aria-hidden className="h-4 w-4" />
              </Button>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
