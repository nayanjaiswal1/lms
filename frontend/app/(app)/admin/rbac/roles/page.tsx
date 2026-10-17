import { notFound } from "next/navigation"
import { apiGet } from "@/lib/server/api"
import { getMyPermissions } from "@/lib/server/permissions"
import { PERMISSIONS } from "@/lib/auth/permission-codes"
import { CreateRoleDialog } from "./create-role-dialog"
import { RoleFilters } from "./role-filters"
import { RoleTable, type Role } from "./role-table"
import { PageHeader } from "@/components/shared/page-header";

async function fetchRoles(): Promise<{ roles: Role[]; total: number }> {
  try {
    const body = await apiGet<{ roles: Role[]; total: number }>("/api/admin/rbac/roles?limit=100")
    return { roles: body.roles ?? [], total: body.total ?? 0 }
  } catch {
    return { roles: [], total: 0 }
  }
}

export default async function RolesPage() {
  const myPerms = await getMyPermissions()
  if (!myPerms.includes(PERMISSIONS.ADMIN.MANAGE_ROLES)) {
    notFound()
  }

  const { roles } = await fetchRoles()

  return (
    <div className="page-container">
      <PageHeader title="Roles" description="Manage permission bundles. System roles are read-only; create custom roles for your org.">
        <CreateRoleDialog />
      </PageHeader>

      {roles.length === 0 ? (
        <div className="empty-state mt-8">
          <p className="text-muted-foreground">No roles yet.</p>
        </div>
      ) : (
        <>
          <div className="mt-6 flex flex-wrap items-center gap-3">
            <RoleFilters />
          </div>
          <div className="mt-6">
            <RoleTable roles={roles} />
          </div>
        </>
      )}
    </div>
  )
}
