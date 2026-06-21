import { notFound } from "next/navigation"
import { cookies } from "next/headers"
import { Badge } from "@/components/ui/badge"
import { getMyPermissions } from "@/lib/server/permissions"
import { PERMISSIONS } from "@/lib/auth/permission-codes"

interface Permission {
  id: string
  code: string
  name: string
  description: string
  module: string
  is_active: boolean
}

async function fetchPermissions(): Promise<Permission[]> {
  const cookieStore = await cookies()
  const token = cookieStore.get("access_token")?.value
  if (!token) return []

  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL
  if (!apiUrl) return []

  try {
    const res = await fetch(`${apiUrl}/api/admin/rbac/permissions?limit=100`, {
      headers: { Cookie: `access_token=${token}` },
      cache: "no-store",
    })
    if (!res.ok) return []
    const body = (await res.json()) as { data: { permissions: Permission[] } }
    return body.data.permissions ?? []
  } catch {
    return []
  }
}

function groupByModule(permissions: Permission[]): Record<string, Permission[]> {
  return permissions.reduce<Record<string, Permission[]>>((acc, p) => {
    if (!acc[p.module]) acc[p.module] = []
    acc[p.module].push(p)
    return acc
  }, {})
}

export default async function PermissionsPage() {
  // Server-side permission check — never pass notFound() as a JSX prop.
  const myPerms = await getMyPermissions()
  if (!myPerms.includes(PERMISSIONS.ADMIN.MANAGE_ROLES) &&
      !myPerms.includes(PERMISSIONS.ADMIN.MANAGE_PERMISSIONS)) {
    notFound()
  }

  const permissions = await fetchPermissions()
  const grouped = groupByModule(permissions)
  const modules = Object.keys(grouped).sort()

  return (
    <div className="page-container py-8">
      <div className="page-header">
        <div>
          <h1 className="page-title">Permission Catalogue</h1>
          <p className="text-muted-foreground mt-1">
            Platform-wide permission codes. Read-only — assigned to roles, not users directly.
          </p>
        </div>
        <Badge variant="outline">{permissions.length} permissions</Badge>
      </div>

      <div className="mt-8 space-y-8">
        {modules.map((module) => (
          <section key={module}>
            <h2 className="section-title capitalize mb-4">{module}</h2>
            <div className="table-responsive">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border text-left text-muted-foreground">
                    <th className="pb-2 pr-6 font-medium">Code</th>
                    <th className="pb-2 pr-6 font-medium">Name</th>
                    <th className="pb-2 font-medium">Description</th>
                  </tr>
                </thead>
                <tbody>
                  {grouped[module].map((p) => (
                    <tr key={p.id} className="border-b border-border last:border-0">
                      <td className="py-3 pr-6">
                        <code className="kbd">{p.code}</code>
                      </td>
                      <td className="py-3 pr-6 font-medium">{p.name}</td>
                      <td className="py-3 text-muted-foreground">{p.description}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        ))}
      </div>
    </div>
  )
}
