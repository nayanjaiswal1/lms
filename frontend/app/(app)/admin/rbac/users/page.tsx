import Link from "next/link"
import { notFound } from "next/navigation"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { getMyPermissions } from "@/lib/server/permissions"
import { apiGet } from "@/lib/server/api"
import { PERMISSIONS } from "@/lib/auth/permission-codes"
import ROUTES from "@/lib/routes"

interface UserSummary {
  id: string
  name: string
  email: string
  avatar_url: string | null
  role_count: number
  joined_at: string
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

  const { search } = await searchParams
  const query = search?.trim() ?? ""
  const qs = query ? `&search=${encodeURIComponent(query)}` : ""
  const { users } = await apiGet<{ users: UserSummary[]; total: number }>(
    `/api/admin/rbac/users?limit=100${qs}`,
  )

  return (
    <div className="page-container py-8">
      <div className="page-header">
        <div>
          <h1 className="page-title">Users</h1>
          <p className="text-muted-foreground mt-1">
            Members of your org and the RBAC roles they hold.
          </p>
        </div>
      </div>

      <form method="GET" className="mt-6 max-w-sm">
        <Input
          type="search"
          name="search"
          placeholder="Search by name or email…"
          defaultValue={query}
        />
      </form>

      <section className="mt-6">
        {users.length === 0 ? (
          <div className="empty-state">
            <p className="text-muted-foreground">No users found.</p>
          </div>
        ) : (
          <UserTable users={users} />
        )}
      </section>
    </div>
  )
}

function UserTable({ users }: { users: UserSummary[] }) {
  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-muted-foreground">
            <th className="pb-2 pr-6 font-medium">Name</th>
            <th className="pb-2 pr-6 font-medium">Email</th>
            <th className="pb-2 pr-6 font-medium">Roles</th>
            <th className="pb-2 font-medium" />
          </tr>
        </thead>
        <tbody>
          {users.map((user) => (
            <tr key={user.id} className="border-b border-border last:border-0">
              <td className="py-3 pr-6 font-medium">{user.name}</td>
              <td className="py-3 pr-6 text-muted-foreground">{user.email}</td>
              <td className="py-3 pr-6">
                <Badge variant={user.role_count > 0 ? "default" : "secondary"}>
                  {user.role_count}
                </Badge>
              </td>
              <td className="py-3 text-right">
                <Button asChild variant="ghost" size="sm">
                  <Link href={`${ROUTES.ADMIN_RBAC_USERS}/${user.id}`}>Manage roles</Link>
                </Button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
