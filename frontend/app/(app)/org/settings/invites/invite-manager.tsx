"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { InviteSendForm } from "./invite-send-form";
import { InviteTable } from "./invite-table";
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
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [invites, setInvites] = useState<Invite[]>(initialInvites);

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
    const res = await revokeInviteAction(orgId, inviteId);
    if (res.error) {
      toast.error(res.error);
      setInvites(initialInvites);
      return;
    }
    toast.success("Invite revoked");
  }

  async function handleBatchRevoke() {
    const ids = Array.from(selected);
    setInvites((prev) => prev.filter((i) => !ids.includes(i.id)));
    setSelected(new Set());
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
    const ids = Array.from(selected);
    const res = await batchResendAction(orgId, ids);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    const count = res.data?.resent_count ?? ids.length;
    toast.success(`Resent ${plural(count, "invite")}`);
    setSelected(new Set());
  }

  return (
    <div className="flex flex-col gap-8 mt-6">
      <InviteSendForm onSend={handleBatchSend} />
      <InviteTable
        invites={invites}
        currentStatus={currentStatus}
        selected={selected}
        onSelectionChange={setSelected}
        onRevoke={handleRevoke}
        onBatchRevoke={handleBatchRevoke}
        onBatchResend={handleBatchResend}
      />
    </div>
  );
}
