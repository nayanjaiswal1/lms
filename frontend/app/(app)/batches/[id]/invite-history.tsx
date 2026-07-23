import { ChevronDown } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import type { BatchInvitation } from "@/lib/server/batches";
import { InviteRowActions } from "@/app/(app)/batches/[id]/invite-row-actions";

interface InviteHistoryProps {
  batchId: string;
  invitations: BatchInvitation[];
}

type InviteStatus = "pending" | "accepted" | "declined" | "expired";

const STATUS_LABEL: Record<InviteStatus, string> = {
  pending:  "Pending",
  accepted: "Accepted",
  declined: "Declined",
  expired:  "Expired",
};

const STATUS_ORDER: InviteStatus[] = ["pending", "accepted", "declined", "expired"];

function inviteStatus(inv: BatchInvitation): InviteStatus {
  if (inv.accepted_at) return "accepted";
  if (inv.declined_at) return "declined";
  if (new Date(inv.expires_at) <= new Date()) return "expired";
  return "pending";
}

function statusBadge(status: InviteStatus) {
  return (
    <Badge
      className={status === "accepted" ? "badge-success" : undefined}
      variant={status === "accepted" ? "outline" : status === "declined" || status === "expired" ? "destructive" : "secondary"}
    >
      {STATUS_LABEL[status]}
    </Badge>
  );
}

// groupByJob clusters invitations sent by the same batch_import job (a bulk
// Excel import, or a single "invite new" — both run through that job) into
// one unit. Invitations with no job on record (e.g. the legacy direct-invite
// endpoint) each get their own single-item group. Groups sort by their most
// recently invited member.
function groupByJob(invitations: BatchInvitation[]): BatchInvitation[][] {
  const groups = new Map<string, BatchInvitation[]>();
  for (const inv of invitations) {
    const key = inv.import_job_id ?? inv.id;
    const list = groups.get(key);
    if (list) list.push(inv);
    else groups.set(key, [inv]);
  }
  return [...groups.values()].sort((a, b) => latestInvitedAt(b) - latestInvitedAt(a));
}

function latestInvitedAt(group: BatchInvitation[]): number {
  return Math.max(...group.map((inv) => new Date(inv.invited_at).getTime()));
}

interface InviteRowProps {
  batchId: string;
  invitation: BatchInvitation;
  indented?: boolean;
}

function InviteRow({ batchId, invitation, indented }: InviteRowProps) {
  const status = inviteStatus(invitation);
  return (
    <div className={`flex items-center gap-3 px-3 py-2.5 text-sm ${indented ? "pl-8" : ""}`}>
      <span className="flex-1 min-w-0 truncate font-medium">{invitation.email}</span>
      <span className="flex items-center gap-1.5 shrink-0">
        {statusBadge(status)}
        {invitation.resent_at && status === "pending" && (
          <span className="text-xs text-muted-foreground">
            resent {new Date(invitation.resent_at).toLocaleDateString()}
          </span>
        )}
      </span>
      <span className="w-20 shrink-0 text-right text-xs text-muted-foreground">
        {new Date(invitation.invited_at).toLocaleDateString()}
      </span>
      <span className="w-16 shrink-0 text-right">
        {status === "pending" && (
          <InviteRowActions batchId={batchId} email={invitation.email} invitationId={invitation.id} />
        )}
      </span>
    </div>
  );
}

interface InviteGroupProps {
  batchId: string;
  group: BatchInvitation[];
}

function InviteGroup({ batchId, group }: InviteGroupProps) {
  if (group.length === 1) {
    return <InviteRow batchId={batchId} invitation={group[0]} />;
  }

  const counts = group.reduce<Partial<Record<InviteStatus, number>>>((acc, inv) => {
    const status = inviteStatus(inv);
    acc[status] = (acc[status] ?? 0) + 1;
    return acc;
  }, {});

  return (
    <details className="group">
      <summary className="flex cursor-pointer list-none items-center gap-3 px-3 py-2.5 text-sm marker:content-none">
        <ChevronDown aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground transition-transform duration-fast group-open:rotate-180" />
        <span className="flex-1 min-w-0 font-medium">{group.length} people invited</span>
        <span className="flex flex-wrap items-center gap-1.5 shrink-0">
          {STATUS_ORDER.filter((s) => counts[s]).map((s) => (
            <Badge className={s === "accepted" ? "badge-success" : undefined} key={s} variant={s === "accepted" ? "outline" : s === "declined" || s === "expired" ? "destructive" : "secondary"}>
              {counts[s]} {STATUS_LABEL[s]}
            </Badge>
          ))}
        </span>
        <span className="w-20 shrink-0 text-right text-xs text-muted-foreground">
          {new Date(latestInvitedAt(group)).toLocaleDateString()}
        </span>
        <span className="w-16 shrink-0" />
      </summary>
      <div className="divide-y divide-border border-t border-border">
        {group.map((inv) => (
          <InviteRow indented batchId={batchId} invitation={inv} key={inv.id} />
        ))}
      </div>
    </details>
  );
}

export function InviteHistory({ batchId, invitations }: InviteHistoryProps) {
  if (invitations.length === 0) return null;

  const groups = groupByJob(invitations);

  return (
    <section aria-label="Invite history" className="divide-y divide-border rounded-md border border-border">
      {groups.map((group) => (
        <InviteGroup batchId={batchId} group={group} key={group[0].import_job_id ?? group[0].id} />
      ))}
    </section>
  );
}
