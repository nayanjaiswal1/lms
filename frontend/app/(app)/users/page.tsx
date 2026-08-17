import { notFound, redirect } from "next/navigation"
import { Badge } from "@/components/ui/badge";
import { getMyPermissions } from "@/lib/server/permissions"
import { apiGet } from "@/lib/server/api"
import { getOrgMembers, getOrgInvites } from "@/lib/orgs/server";
import type { Member } from "@/lib/orgs/types";
import { PERMISSIONS } from "@/lib/auth/permission-codes"
import ROUTES from "@/lib/routes"
import { UserFilters } from "@/app/(app)/users/user-filters"
import { UserSearchInput } from "@/app/(app)/users/user-search-input"
import { UserTable, type MergedUser, type RoleOption, type UserSummary } from "@/app/(app)/users/user-table"
import { AddPeoplePanel } from "@/app/(app)/users/add-people-panel";
import { InviteList } from "@/app/(app)/users/invite-list";
import { getCurrentOrgId } from "@/lib/server/claims";

// Merges the two permission-gated fetches below into one row per person —
// `members` carries org role/invite data (MANAGE_ORG), `users` carries RBAC
// roles/account status (VIEW_MEMBERS). Either can be empty if the caller
// lacks that permission; the row just shows "—" / no roles for that half.
function mergeUsers(members: Member[], users: UserSummary[]): MergedUser[] {
  const memberByUserId = new Map(members.map((m) => [m.user_id, m]))
  const seen = new Set<string>()

  const fromUsers = users.map((u): MergedUser => {
    const member = memberByUserId.get(u.id)
    seen.add(u.id)
    return {
      id: u.id,
      memberId: u.member_id,
      name: u.name,
      email: u.email,
      avatarUrl: u.avatar_url,
      orgRole: member?.role ?? null,
      roleNames: u.role_names,
      status: u.status,
      accountStatus: u.account_status,
      joinedAt: member?.joined_at ?? u.joined_at,
    }
  })

  const fromMembersOnly = members
    .filter((m) => !seen.has(m.user_id))
    .map((m): MergedUser => ({
      id: m.user_id,
      memberId: m.id,
      name: m.name,
      email: m.email,
      avatarUrl: m.avatar_url,
      orgRole: m.role,
      roleNames: [],
      status: m.status,
      accountStatus: null,
      joinedAt: m.joined_at,
    }))

  return [...fromUsers, ...fromMembersOnly]
}


export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string }>
}) {
  const myPerms = await getMyPermissions()
  const canViewMembers = myPerms.includes(PERMISSIONS.ADMIN.VIEW_MEMBERS)
  const canManageOrg = myPerms.includes(PERMISSIONS.ADMIN.MANAGE_ORG)
  if (!canViewMembers && !canManageOrg) notFound()

  const orgId = await getCurrentOrgId()
  if (!orgId) redirect(ROUTES.ORG_SELECT)

  const { search } = await searchParams
  const query = search?.trim() ?? ""
  const qs = query ? `&search=${encodeURIComponent(query)}` : ""

  const [usersData, orgData] = await Promise.all([
    canViewMembers
      ? Promise.all([
          apiGet<{ users: UserSummary[]; total: number }>(`/api/admin/rbac/users?limit=100${qs}`),
          apiGet<{ roles: RoleOption[] }>(`/api/admin/rbac/roles?limit=100&active=true`),
        ])
      : null,
    canManageOrg ? Promise.all([getOrgMembers(orgId), getOrgInvites(orgId)]) : null,
  ])

  const users = usersData?.[0].users ?? []
  const roles = usersData?.[1].roles ?? []
  const memberPage = orgData?.[0]
  const invitePage = orgData?.[1]
  const pendingCount = invitePage
    ? invitePage.invites.filter((inv) => inv.accepted_at === null && inv.revoked_at === null).length
    : 0
  const mergedUsers = mergeUsers(memberPage?.members ?? [], users)

  return (
    <div className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">Users</h1>
          <p className="text-muted-foreground mt-1">
            Members of your org, their org role, and the RBAC roles they hold.
          </p>
        </div>
      </div>

      {canManageOrg && pendingCount > 0 && (
        <section className="mt-6 card-base p-6">
          <div className="flex items-center gap-2 mb-4">
            <h2 className="subsection-title text-foreground">Pending Invites</h2>
            <Badge variant="secondary">{pendingCount}</Badge>
          </div>
          <InviteList invites={invitePage?.invites ?? []} orgId={orgId} />
        </section>
      )}

      {(canViewMembers || canManageOrg) && (
        <div className="mt-8">
          {/* One bordered bar instead of loose floating controls — search +
              filters are one filtering system, so they read as one grouped
              unit; Add people sits apart, right-aligned, since it isn't a
              filter. The role-icon legend moved to the Roles column header
              itself — that's where the icons needing decoding actually live. */}
          <div className="flex flex-wrap items-center gap-2 rounded-lg border border-border bg-card p-2.5">
            <UserSearchInput />
            <UserFilters roleOptions={roles} />
            {canManageOrg && (
              <div className="ml-auto">
                <AddPeoplePanel orgId={orgId} />
              </div>
            )}
          </div>

          <section className="mt-6">
            {mergedUsers.length === 0 ? (
              <div className="empty-state">
                <p className="text-muted-foreground">No users found.</p>
              </div>
            ) : (
              <UserTable orgId={orgId} users={mergedUsers} />
            )}
          </section>
        </div>
      )}
    </div>
  )
}
