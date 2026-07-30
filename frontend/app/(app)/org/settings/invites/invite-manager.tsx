"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { InviteSendForm } from "./invite-send-form";
import { InviteTable } from "./invite-table";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import {
  batchInviteAction,
  batchRevokeAction,
  batchResendAction,
  revokeInviteAction,
} from "./actions";

export interface Invite {
  id: string;
  email: string;
  role: string;
  invited_by: string;
  expires_at: string;
  accepted_at: string | null;
  revoked_at: string | null;
  created_at: string;
}

interface InviteManagerProps {
  orgId: string;
  initialInvites: Invite[];
  initialNextCursor: string;
  currentStatus: string;
}

interface RevokeUiState {
  selected: Set<string>;
  confirmId: string | null;
  confirmBatch: boolean;
}

function plural(n: number, word: string): string {
  return `${n} ${word}${n === 1 ? "" : "s"}`;
}

export function InviteManager({
  orgId,
  initialInvites,
  initialNextCursor: _initialNextCursor,
  currentStatus,
}: InviteManagerProps) {
  const router = useRouter();
  const [invites, setInvites] = useState<Invite[]>(initialInvites);
  const [ui, setUi] = useState<RevokeUiState>({ selected: new Set(), confirmId: null, confirmBatch: false });

  async function handleBatchSend(emails: string[], role: string) {
    const res = await batchInviteAction(orgId, emails, role);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    const d = res.data;
    if (!d) return;
    toast.success(`Queued ${plural(d.queued, "invite")} across ${plural(d.job_count, "job")}`);
    if (d.skipped.length > 0) {
      const reasons = d.skipped.map((s) => `${s.email} (${s.reason})`).join(", ");
      toast.warning(`${d.skipped.length} skipped: ${reasons}`);
    }
    router.refresh();
  }

  async function handleRevoke(inviteId: string) {
    setInvites((prev) => prev.filter((i) => i.id !== inviteId));
    setUi((u) => ({ ...u, confirmId: null }));
    const res = await revokeInviteAction(orgId, inviteId);
    if (res.error) {
      toast.error(res.error);
      setInvites(initialInvites);
      return;
    }
    toast.success("Invite revoked");
  }

  async function handleBatchRevoke() {
    const ids = Array.from(ui.selected);
    setInvites((prev) => prev.filter((i) => !ids.includes(i.id)));
    setUi((u) => ({ ...u, selected: new Set(), confirmBatch: false }));
    const res = await batchRevokeAction(orgId, ids);
    if (res.error) {
      toast.error(res.error);
      setInvites(initialInvites);
      return;
    }
    const count = res.data?.revoked ?? ids.length;
    toast.success(`Revoked ${plural(count, "invite")}`);
  }

  async function handleBatchResend() {
    const ids = Array.from(ui.selected);
    const res = await batchResendAction(orgId, ids);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    const count = res.data?.resent_count ?? ids.length;
    toast.success(`Resent ${plural(count, "invite")}`);
    setUi((u) => ({ ...u, selected: new Set() }));
  }

  const confirmInvite = ui.confirmId ? invites.find((i) => i.id === ui.confirmId) : undefined;

  return (
    <div className="flex flex-col gap-8 mt-6">
      <InviteSendForm onSend={handleBatchSend} />
      <InviteTable
        currentStatus={currentStatus}
        invites={invites}
        selected={ui.selected}
        onBatchRevoke={() => setUi((u) => ({ ...u, confirmBatch: true }))}
        onBatchResend={handleBatchResend}
        onRevoke={(inviteId) => setUi((u) => ({ ...u, confirmId: inviteId }))}
        onSelectionChange={(sel) => setUi((u) => ({ ...u, selected: sel }))}
      />

      <ConfirmDialog
        destructive
        confirmLabel="Revoke"
        description={confirmInvite ? `This revokes the invite to ${confirmInvite.email}. They will no longer be able to join with this link.` : ""}
        open={ui.confirmId !== null}
        title="Revoke invite?"
        onConfirm={() => ui.confirmId && handleRevoke(ui.confirmId)}
        onOpenChange={(open) => !open && setUi((u) => ({ ...u, confirmId: null }))}
      />
      <ConfirmDialog
        destructive
        confirmLabel={`Revoke (${ui.selected.size})`}
        description={`This revokes ${plural(ui.selected.size, "invite")}. They will no longer be able to join with their links.`}
        open={ui.confirmBatch}
        title="Revoke selected invites?"
        onConfirm={handleBatchRevoke}
        onOpenChange={(open) => !open && setUi((u) => ({ ...u, confirmBatch: false }))}
      />
    </div>
  );
}
