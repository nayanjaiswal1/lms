"use client";

import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";
import type { Invite } from "./invite-manager";

const STATUS_TABS = [
  { label: "Pending",  value: "pending" },
  { label: "Accepted", value: "accepted" },
  { label: "Revoked",  value: "revoked" },
  { label: "Expired",  value: "expired" },
  { label: "All",      value: "all" },
] as const;

type BadgeVariant = "default" | "secondary" | "destructive" | "outline";

function resolveStatus(invite: Invite): string {
  if (invite.accepted_at) return "accepted";
  if (invite.revoked_at) return "revoked";
  if (new Date(invite.expires_at) < new Date()) return "expired";
  return "pending";
}

function resolveStatusVariant(status: string): BadgeVariant {
  if (status === "accepted") return "default";
  if (status === "revoked") return "destructive";
  if (status === "expired") return "outline";
  return "secondary";
}

function formatRelative(date: string): string {
  const diff = Date.now() - new Date(date).getTime();
  const rtf = new Intl.RelativeTimeFormat("en", { numeric: "auto" });
  const seconds = Math.round(diff / 1000);
  const minutes = Math.round(seconds / 60);
  const hours = Math.round(minutes / 60);
  const days = Math.round(hours / 24);
  if (Math.abs(days) >= 1) return rtf.format(-days, "day");
  if (Math.abs(hours) >= 1) return rtf.format(-hours, "hour");
  if (Math.abs(minutes) >= 1) return rtf.format(-minutes, "minute");
  return rtf.format(-seconds, "second");
}

function formatExpiry(expiresAt: string, status: string): string {
  if (status !== "pending") return "—";
  const diff = new Date(expiresAt).getTime() - Date.now();
  if (diff <= 0) return "expired";
  const days = Math.floor(diff / (1000 * 60 * 60 * 24));
  const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
  if (days > 0) return `${days}d ${hours}h`;
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

interface InviteTableProps {
  invites: Invite[];
  currentStatus: string;
  selected: Set<string>;
  onSelectionChange: (sel: Set<string>) => void;
  onRevoke: (inviteId: string) => void;
  onBatchRevoke: () => void;
  onBatchResend: () => void;
}

export function InviteTable({
  invites,
  currentStatus,
  selected,
  onSelectionChange,
  onRevoke,
  onBatchRevoke,
  onBatchResend,
}: InviteTableProps) {
  const pendingInvites = invites.filter((i) => resolveStatus(i) === "pending");
  const allSelected =
    pendingInvites.length > 0 && pendingInvites.every((i) => selected.has(i.id));
  const someSelected =
    pendingInvites.some((i) => selected.has(i.id)) && !allSelected;

  function toggleSelectAll() {
    if (allSelected) {
      onSelectionChange(new Set());
    } else {
      onSelectionChange(new Set(pendingInvites.map((i) => i.id)));
    }
  }

  function toggleOne(id: string) {
    const next = new Set(selected);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    onSelectionChange(next);
  }

  const heading =
    currentStatus === "all"
      ? "All Invites"
      : `${currentStatus.charAt(0).toUpperCase()}${currentStatus.slice(1)} Invites`;

  return (
    <section className="flex flex-col gap-4">
      <h2 className="section-title">{heading}</h2>

      <div className="flex flex-wrap items-center gap-2" role="tablist" aria-label="Filter invites by status">
        {STATUS_TABS.map((tab) => (
          <Link
            key={tab.value}
            href={`${ROUTES.ORG_SETTINGS_INVITES}?status=${tab.value}`}
            role="tab"
            aria-selected={currentStatus === tab.value}
            className={cn(
              "text-xs px-3 py-1.5 rounded border transition-colors",
              currentStatus === tab.value
                ? "bg-primary text-primary-foreground border-primary"
                : "border-border text-muted-foreground hover:border-primary/40 hover:text-foreground",
            )}
          >
            {tab.label}
          </Link>
        ))}
      </div>

      {selected.size > 0 && (
        <div className="flex flex-wrap items-center gap-3 p-3 rounded-md bg-muted border border-border">
          <span className="text-sm text-muted-foreground shrink-0">
            {selected.size} selected
          </span>
          <Button size="sm" variant="destructive" onClick={onBatchRevoke}>
            Revoke ({selected.size})
          </Button>
          <Button size="sm" variant="outline" onClick={onBatchResend}>
            Resend ({selected.size})
          </Button>
        </div>
      )}

      {invites.length === 0 ? (
        <div className="empty-state py-10">
          <p className="font-medium">
            No {currentStatus === "all" ? "" : `${currentStatus} `}invites
          </p>
          <p className="text-sm text-muted-foreground">
            {currentStatus === "pending"
              ? "Send invitations using the form above."
              : "Nothing to show for this filter."}
          </p>
        </div>
      ) : (
        <div className="table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-xs text-muted-foreground">
                <th className="pb-2 pr-3 w-8">
                  <Checkbox
                    checked={allSelected ? true : someSelected ? "indeterminate" : false}
                    onCheckedChange={toggleSelectAll}
                    aria-label="Select all pending invites"
                  />
                </th>
                <th className="pb-2 pr-4 font-medium">Email</th>
                <th className="pb-2 pr-4 font-medium hidden sm:table-cell">Role</th>
                <th className="pb-2 pr-4 font-medium">Status</th>
                <th className="pb-2 pr-4 font-medium hidden md:table-cell">Sent</th>
                <th className="pb-2 pr-4 font-medium hidden md:table-cell">Expires</th>
                <th className="pb-2 font-medium sr-only">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {invites.map((invite) => {
                const status = resolveStatus(invite);
                const isPending = status === "pending";
                return (
                  <tr
                    key={invite.id}
                    className="hover:bg-muted/30 transition-colors duration-fast"
                  >
                    <td className="py-3 pr-3">
                      <Checkbox
                        checked={selected.has(invite.id)}
                        onCheckedChange={() => toggleOne(invite.id)}
                        disabled={!isPending}
                        aria-label={`Select ${invite.email}`}
                      />
                    </td>
                    <td className="py-3 pr-4 font-medium">{invite.email}</td>
                    <td className="py-3 pr-4 hidden sm:table-cell">
                      <Badge variant="outline" className="capitalize">
                        {invite.role}
                      </Badge>
                    </td>
                    <td className="py-3 pr-4">
                      <Badge variant={resolveStatusVariant(status)} className="capitalize">
                        {status}
                      </Badge>
                    </td>
                    <td className="py-3 pr-4 text-muted-foreground hidden md:table-cell">
                      {formatRelative(invite.created_at)}
                    </td>
                    <td className="py-3 pr-4 text-muted-foreground hidden md:table-cell">
                      {formatExpiry(invite.expires_at, status)}
                    </td>
                    <td className="py-3 text-right">
                      {isPending && (
                        <Button
                          size="sm"
                          variant="ghost"
                          onClick={() => onRevoke(invite.id)}
                          className="h-7 px-2 text-destructive hover:text-destructive"
                        >
                          Revoke
                        </Button>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
