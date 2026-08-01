"use client";

import { parseAsStringLiteral, useQueryState } from "nuqs";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";
import { useRowSelection } from "@/hooks/use-row-selection";
import { UserActionsMenu } from "@/app/(app)/users/user-actions-menu";
import { ManageRolesDialog } from "@/app/(app)/users/manage-roles-dialog";
import { RoleBadges } from "@/app/(app)/users/role-badges";
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

interface Props {
  users: UserSummary[];
  orgId: string;
}

function statusBadgeVariant(status: string): "default" | "destructive" {
  return status === "suspended" ? "destructive" : "default";
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
    if (roleName !== "all" && !u.role_names.includes(roleName)) return false;
    return true;
  });

  const selection = useRowSelection(filtered.map((u) => u.id));
  const selectedMemberIds = filtered
    .filter((u) => selection.isSelected(u.id))
    .map((u) => u.member_id);

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
                <th className="pb-2 pr-6 font-medium">Email</th>
                <th className="pb-2 pr-6 font-medium">Roles</th>
                <th className="pb-2 pr-6 font-medium">Status</th>
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
                  <td className="py-3 pr-6 font-medium">{user.name}</td>
                  <td className="py-3 pr-6 text-muted-foreground">{user.email}</td>
                  <td className="py-3 pr-6">
                    <RoleBadges roleNames={user.role_names} />
                  </td>
                  <td className="py-3 pr-6">
                    <Badge variant={statusBadgeVariant(user.status)}>{user.status}</Badge>
                  </td>
                  <td className="py-3 text-right">
                    <UserActionsMenu
                      accountStatus={user.account_status}
                      email={user.email}
                      memberId={user.member_id}
                      name={user.name}
                      orgId={orgId}
                      status={user.status}
                      userId={user.id}
                    />
                    <ManageRolesDialog userId={user.id} userName={user.name} />
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
