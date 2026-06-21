"use client";

import { useActionState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { Member, OrgRole, MemberStatus } from "@/lib/orgs/types";
import {
  updateMemberAction,
  removeMemberAction,
  type MemberActionState,
} from "@/app/org/settings/members/actions";

const ROLE_OPTIONS: { value: OrgRole; label: string }[] = [
  { value: "owner",      label: "Owner" },
  { value: "admin",      label: "Admin" },
  { value: "instructor", label: "Instructor" },
  { value: "mentor",     label: "Mentor" },
  { value: "learner",    label: "Learner" },
];

function roleBadgeClass(role: string): string {
  switch (role) {
    case "owner":      return "bg-primary text-primary-foreground";
    case "admin":      return "bg-muted text-foreground";
    case "instructor": return "bg-muted text-foreground";
    case "mentor":     return "bg-muted text-foreground";
    default:           return "bg-muted text-muted-foreground";
  }
}

function statusBadgeVariant(
  status: MemberStatus,
): "default" | "secondary" | "destructive" | "outline" {
  switch (status) {
    case "active":    return "default";
    case "suspended": return "destructive";
    case "removed":   return "outline";
    default:          return "secondary";
  }
}

// ─── Role change form ──────────────────────────────────────────────────────────

interface RoleFormProps {
  member: Member;
  orgId: string;
}

function RoleForm({ member, orgId }: RoleFormProps) {
  const [state, action, isPending] = useActionState<MemberActionState, FormData>(
    updateMemberAction,
    {},
  );

  return (
    <form action={action}>
      <input type="hidden" name="org_id" value={orgId} />
      <input type="hidden" name="member_id" value={member.id} />
      <div className="flex items-center gap-2">
        {/* shadcn Select serialises the value via the hidden input Radix injects */}
        <Select defaultValue={member.role} name="role">
          <SelectTrigger
            aria-label={`Change role for ${member.name}`}
            className="w-full sm:w-36 h-8 text-xs"
          >
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {ROLE_OPTIONS.map((opt) => (
              <SelectItem key={opt.value} value={opt.value}>
                {opt.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Button
          aria-label={`Save role for ${member.name}`}
          disabled={isPending}
          size="sm"
          type="submit"
          variant="secondary"
        >
          {isPending ? "Saving…" : "Set"}
        </Button>
      </div>
      {state.error && (
        <p className="text-xs text-destructive mt-1" role="alert">{state.error}</p>
      )}
    </form>
  );
}

// ─── Status form ───────────────────────────────────────────────────────────────

interface StatusFormProps {
  member: Member;
  orgId: string;
}

function StatusForm({ member, orgId }: StatusFormProps) {
  const [state, action, isPending] = useActionState<MemberActionState, FormData>(
    updateMemberAction,
    {},
  );
  const newStatus = member.status === "suspended" ? "active" : "suspended";

  return (
    <form action={action}>
      <input type="hidden" name="org_id" value={orgId} />
      <input type="hidden" name="member_id" value={member.id} />
      <input type="hidden" name="status" value={newStatus} />
      <Button
        aria-label={
          member.status === "suspended"
            ? `Unsuspend ${member.name}`
            : `Suspend ${member.name}`
        }
        disabled={isPending}
        size="sm"
        type="submit"
        variant="secondary"
      >
        {member.status === "suspended" ? "Unsuspend" : "Suspend"}
      </Button>
      {state.error && (
        <p className="text-xs text-destructive mt-1" role="alert">{state.error}</p>
      )}
    </form>
  );
}

// ─── Remove form ───────────────────────────────────────────────────────────────

interface RemoveFormProps {
  member: Member;
  orgId: string;
}

function RemoveForm({ member, orgId }: RemoveFormProps) {
  const [state, action, isPending] = useActionState<MemberActionState, FormData>(
    removeMemberAction,
    {},
  );

  return (
    <form action={action}>
      <input type="hidden" name="org_id" value={orgId} />
      <input type="hidden" name="member_id" value={member.id} />
      <Button
        aria-label={`Remove ${member.name} from organisation`}
        disabled={isPending}
        size="sm"
        type="submit"
        variant="destructive"
      >
        Remove
      </Button>
      {state.error && (
        <p className="text-xs text-destructive mt-1" role="alert">{state.error}</p>
      )}
    </form>
  );
}

// ─── Member row ────────────────────────────────────────────────────────────────

interface MemberRowProps {
  member: Member;
  orgId: string;
}

function MemberRow({ member, orgId }: MemberRowProps) {
  return (
    <div className="flex flex-col gap-3 py-4 border-b border-border last:border-0 sm:flex-row sm:items-start">
      {/* Avatar + identity */}
      <div className="flex items-center gap-3 flex-1 min-w-0">
        <div className="h-9 w-9 rounded-full bg-muted flex items-center justify-center flex-shrink-0 text-sm font-medium text-foreground overflow-hidden">
          {member.avatar_url ? (
            /* eslint-disable-next-line @next/next/no-img-element */
            <img
              alt={member.name}
              className="h-9 w-9 rounded-full object-cover"
              src={member.avatar_url}
            />
          ) : (
            member.name.charAt(0).toUpperCase()
          )}
        </div>
        <div className="min-w-0">
          <p className="text-sm font-medium text-foreground truncate">{member.name}</p>
          <p className="text-xs text-muted-foreground truncate">{member.email}</p>
        </div>
      </div>

      {/* Badges */}
      <div className="flex items-center gap-2 flex-wrap">
        <Badge className={roleBadgeClass(member.role)} variant="outline">
          {member.role}
        </Badge>
        <Badge variant={statusBadgeVariant(member.status as MemberStatus)}>
          {member.status}
        </Badge>
      </div>

      {/* Actions */}
      <div className="flex flex-wrap items-start gap-2">
        <RoleForm member={member} orgId={orgId} />
        <StatusForm member={member} orgId={orgId} />
        <RemoveForm member={member} orgId={orgId} />
      </div>
    </div>
  );
}

// ─── Table ─────────────────────────────────────────────────────────────────────

interface MemberTableProps {
  members: Member[];
  orgId: string;
}

export function MemberTable({ members, orgId }: MemberTableProps) {
  if (members.length === 0) {
    return (
      <div className="empty-state py-10">
        <p className="text-muted-foreground text-sm">No members yet.</p>
      </div>
    );
  }

  return (
    <div>
      {members.map((member) => (
        <MemberRow key={member.id} member={member} orgId={orgId} />
      ))}
    </div>
  );
}
