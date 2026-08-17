"use client";

import { parseAsStringLiteral, useQueryState } from "nuqs";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";
import { UserLink } from "@/components/shared/user-link";
import { useRowSelection } from "@/hooks/use-row-selection";
import type { OrgRole } from "@/lib/orgs/types";
import { UserActionsMenu } from "@/app/(app)/users/user-actions-menu";
import { ManageRolesDialog } from "@/app/(app)/users/manage-roles-dialog";
import { ManageFeaturesDialog } from "@/app/(app)/users/manage-features-dialog";
import { RoleBadges } from "@/app/(app)/users/role-badges";
import { RoleLegend } from "@/app/(app)/users/role-legend";
import { UserBulkActions } from "@/app/(app)/users/user-bulk-actions";
import { STATUS_FILTERS } from "@/app/(app)/users/user-filters";

export interface UserSummary {
  id: string;
  member_id: string;
  name: string;
  email: string;
  avatar_url: string | null;
  role_names: string[];
  /** Org-membership status, scoped to this org. */
  status: string;
  /** Platform account status — whether they can sign in at all. */
  account_status: string;
  joined_at: string;
}

export interface RoleOption {
  id: string;
  name: string;
}

/** One row of the merged table: org membership (role/status) + RBAC roles, keyed by user. */
export interface MergedUser {
  id: string;
  memberId: string;
  name: string;
  email: string;
  avatarUrl: string | null;
  /** null when the caller can't see org-membership data (no MANAGE_ORG/VIEW_MEMBERS). */
  orgRole: OrgRole | null;
  roleNames: string[];
  status: string;
  accountStatus: string | null;
  joinedAt: string;
}

interface Props {
  users: MergedUser[];
  orgId: string;
}

function orgRoleBadgeClass(role: string): string {
  switch (role) {
    case "owner": return "bg-primary text-primary-foreground";
    case "admin": return "bg-muted text-foreground";
    default:      return "bg-muted text-muted-foreground";
  }
}

// Search already narrows `users` server-side (see page.tsx); status/role stay
// as client-side filters over that same result set, matching the pattern in
// app/(app)/batches/[id]/people-list.tsx. The filter controls themselves live
// in UserFilters (same toolbar row as search) — both read the same `status`/
// `role` URL params via nuqs, which keeps every subscriber in sync.
export function UserTable({ users, orgId }: Props) {
  const [status] = useQueryState("status", parseAsStringLiteral(STATUS_FILTERS).withDefault("all"));
  // URL param is the role NAME, not its id — see user-filters.tsx.
  const [roleName] = useQueryState("role", { defaultValue: "all" });

  const filtered = users.filter((u) => {
    if (status !== "all" && u.status !== status) return false;
    if (roleName !== "all" && !u.roleNames.includes(roleName)) return false;
    return true;
  });

  const selection = useRowSelection(filtered.map((u) => u.id));
  const selectedMemberIds = filtered
    .filter((u) => selection.isSelected(u.id))
    .map((u) => u.memberId);

  return (
    <div className="flex flex-col gap-4">
      <p className="text-sm text-muted-foreground">
        {filtered.length} of {users.length} {users.length === 1 ? "user" : "users"}
      </p>

      <UserBulkActions
        count={selection.selected.size}
        memberIds={selectedMemberIds}
        orgId={orgId}
        onDone={selection.clear}
      />

      {filtered.length === 0 ? (
        <div className="empty-state">
          <p className="text-muted-foreground">No users match these filters.</p>
        </div>
      ) : (
        <div className="table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-muted-foreground whitespace-nowrap">
                <th className="w-8 pb-2 pr-3">
                  <Checkbox
                    aria-label="Select all users"
                    checked={selection.allSelected ? true : selection.someSelected ? "indeterminate" : false}
                    onCheckedChange={selection.toggleAll}
                  />
                </th>
                <th className="pb-2 pr-6 font-medium">Name</th>
                <th className="pb-2 pr-6 font-medium">
                  <span className="inline-flex items-center gap-0.5">
                    Roles
                    <RoleLegend />
                  </span>
                </th>
                <th className="pb-2 font-medium" />
              </tr>
            </thead>
            <tbody>
              {filtered.map((user) => (
                <tr className="border-b border-border last:border-0 whitespace-nowrap" key={user.id}>
                  <td className="py-3 pr-3">
                    <Checkbox
                      aria-label={`Select ${user.name}`}
                      checked={selection.isSelected(user.id)}
                      onCheckedChange={() => selection.toggle(user.id)}
                    />
                  </td>
                  <td className="py-3 pr-6">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="relative flex-shrink-0">
                        <div className="h-8 w-8 rounded-full bg-muted flex items-center justify-center text-xs font-medium text-foreground overflow-hidden">
                          {user.avatarUrl ? (
                            /* eslint-disable-next-line @next/next/no-img-element */
                            <img
                              alt={user.name}
                              className="h-8 w-8 rounded-full object-cover"
                              src={user.avatarUrl}
                            />
                          ) : (
                            user.name.charAt(0).toUpperCase()
                          )}
                        </div>
                        {/* Quick-glance echo of the Status column's badge,
                            same "only the exception is worth a mark" rule —
                            skipped for active so most avatars stay plain. */}
                        {user.status !== "active" && (
                          <span
                            aria-hidden
                            className={`absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full ring-2 ring-background ${
                              user.status === "suspended" ? "bg-destructive" : "bg-muted-foreground"
                            }`}
                          />
                        )}
                      </div>
                      <div className="min-w-0">
                        {/* div, not p — globals.css sets `p { leading-7 }` for
                            prose, which blows out the gap between two small
                            stacked lines like this (see lab-usage-view.tsx
                            for the same fix on the same name+email pattern). */}
                        <div className="truncate">
                          <UserLink className="font-medium text-foreground hover:underline" userId={user.id}>
                            {user.name}
                          </UserLink>
                          {/* Status folded in here instead of its own column —
                              active is the default for nearly every row, so
                              showing it every time was a wall of identical
                              badges. Only the exceptions get a mark. Literal
                              superscript, like an exponent, not a pill badge. */}
                          {user.status !== "active" && (
                            <sup
                              className={`ml-1 font-semibold ${
                                user.status === "suspended" ? "text-destructive" : "text-muted-foreground"
                              }`}
                            >
                              {user.status}
                            </sup>
                          )}
                          {user.accountStatus && user.accountStatus !== "active" && (
                            <sup className="ml-1 font-semibold text-destructive">{user.accountStatus}</sup>
                          )}
                        </div>
                        <div className="text-xs text-muted-foreground truncate">{user.email}</div>
                      </div>
                    </div>
                  </td>
                  <td className="py-3 pr-6">
                    {/* Read-only here — two distinct backend systems (org
                        membership role vs RBAC role assignment, see
                        actions.ts) shown as one column since both answer
                        "what can this person do". Edited via the row's
                        Manage roles dialog, not inline. */}
                    <div className="flex items-center gap-2 flex-wrap">
                      {user.orgRole && (
                        <Badge className={orgRoleBadgeClass(user.orgRole)} variant="outline">
                          {user.orgRole}
                        </Badge>
                      )}
                      <RoleBadges roleNames={user.roleNames} />
                    </div>
                  </td>
                  <td className="py-3 text-right">
                    <div className="flex items-center justify-end gap-1">
                      <ManageFeaturesDialog orgId={orgId} userId={user.id} userName={user.name} />
                      <UserActionsMenu
                        accountStatus={user.accountStatus ?? "active"}
                        email={user.email}
                        memberId={user.memberId}
                        name={user.name}
                        orgId={orgId}
                        status={user.status}
                        userId={user.id}
                      />
                      <ManageRolesDialog
                        memberId={user.memberId}
                        orgId={orgId}
                        orgRole={user.orgRole}
                        userId={user.id}
                        userName={user.name}
                      />
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
