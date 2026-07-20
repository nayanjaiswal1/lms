import Link from "next/link"
import { notFound } from "next/navigation"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { apiGet } from "@/lib/server/api"
import { getMyPermissions } from "@/lib/server/permissions"
import { PERMISSIONS } from "@/lib/auth/permission-codes"
import ROUTES from "@/lib/routes"

interface Role {
  id: string
  name: string
  description: string
  is_system: boolean
  is_editable: boolean
  is_active: boolean
  tenant_id: string | null
}

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
  const systemRoles = roles.filter((r) => r.is_system)
  const customRoles = roles.filter((r) => !r.is_system)

  return (
    <div className="page-container py-8">
      <div className="page-header">
        <div>
          <h1 className="page-title">Roles</h1>
          <p className="text-muted-foreground mt-1">
            Manage permission bundles. System roles are read-only; create custom roles for your org.
          </p>
        </div>
        <Button asChild>
          <Link href={ROUTES.ADMIN_RBAC_ROLES_NEW}>New Role</Link>
        </Button>
      </div>

        {systemRoles.length > 0 && (
          <section className="mt-8">
            <h2 className="section-title mb-4">System Roles</h2>
            <RoleTable roles={systemRoles} />
          </section>
        )}

        <section className="mt-8">
          <h2 className="section-title mb-4">Custom Roles</h2>
          {customRoles.length === 0 ? (
            <div className="empty-state">
              <p className="text-muted-foreground">No custom roles yet.</p>
              <Button asChild className="mt-4">
                <Link href={ROUTES.ADMIN_RBAC_ROLES_NEW}>Create your first role</Link>
              </Button>
            </div>
          ) : (
            <RoleTable roles={customRoles} />
          )}
        </section>
    </div>
  )
}

function RoleTable({ roles }: { roles: Role[] }) {
  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-muted-foreground">
            <th className="pb-2 pr-6 font-medium">Name</th>
            <th className="pb-2 pr-6 font-medium">Description</th>
            <th className="pb-2 pr-6 font-medium">Status</th>
            <th className="pb-2 font-medium" />
          </tr>
        </thead>
        <tbody>
          {roles.map((role) => (
            <tr key={role.id} className="border-b border-border last:border-0">
              <td className="py-3 pr-6 font-medium">
                {role.name}
                {role.is_system && (
                  <Badge variant="outline" className="ml-2 text-xs">
                    System
                  </Badge>
                )}
              </td>
              <td className="py-3 pr-6 text-muted-foreground">{role.description}</td>
              <td className="py-3 pr-6">
                {role.is_active ? (
                  <Badge variant="default">Active</Badge>
                ) : (
                  <Badge variant="secondary">Disabled</Badge>
                )}
              </td>
              <td className="py-3 text-right">
                <Button asChild variant="ghost" size="sm">
                  <Link href={`/admin/rbac/roles/${role.id}`}>
                    {role.is_editable ? "Edit" : "View"}
                  </Link>
                </Button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
