import { cookies } from "next/headers"
import { notFound, redirect } from "next/navigation"
import { getMyPermissions } from "@/lib/server/permissions"
import { apiGet } from "@/lib/server/api"
import { PERMISSIONS } from "@/lib/auth/permission-codes"
import ROUTES from "@/lib/routes"
import { RoleLegend } from "@/app/(app)/users/role-legend"
import { UserFilters } from "@/app/(app)/users/user-filters"
import { UserSearchInput } from "@/app/(app)/users/user-search-input"
import { UserTable, type RoleOption, type UserSummary } from "@/app/(app)/users/user-table"

async function getCurrentOrgId(): Promise<string | null> {
  const store = await cookies()
  const token = store.get("access_token")?.value
  if (!token) return null
  try {
    const parts = token.split(".")
    if (parts.length !== 3) return null
    const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString()) as {
      org_id?: string
    }
    return payload.org_id ?? null
  } catch {
    return null
  }
}

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string }>
}) {
  const myPerms = await getMyPermissions()
  if (!myPerms.includes(PERMISSIONS.ADMIN.VIEW_MEMBERS)) {
    notFound()
  }

  const orgId = await getCurrentOrgId()
  if (!orgId) redirect(ROUTES.ORG_SELECT)

  const { search } = await searchParams
  const query = search?.trim() ?? ""
  const qs = query ? `&search=${encodeURIComponent(query)}` : ""
  const [{ users }, { roles }] = await Promise.all([
    apiGet<{ users: UserSummary[]; total: number }>(`/api/admin/rbac/users?limit=100${qs}`),
    apiGet<{ roles: RoleOption[] }>(`/api/admin/rbac/roles?limit=100&active=true`),
  ])

  return (
    <div className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">Users</h1>
          <p className="text-muted-foreground mt-1">
            Members of your org and the RBAC roles they hold.
          </p>
        </div>
      </div>

      <div className="mt-6 flex flex-wrap items-center gap-3">
        <UserSearchInput />
        <UserFilters roleOptions={roles} />
        <div className="sm:ml-auto">
          <RoleLegend />
        </div>
      </div>

      <section className="mt-6">
        {users.length === 0 ? (
          <div className="empty-state">
            <p className="text-muted-foreground">No users found.</p>
          </div>
        ) : (
          <UserTable orgId={orgId} users={users} />
        )}
      </section>
    </div>
  )
}
