import { notFound } from "next/navigation"
import { cookies } from "next/headers"
import { Badge } from "@/components/ui/badge"
import { getMyPermissions } from "@/lib/server/permissions"
import { PERMISSIONS } from "@/lib/auth/permission-codes"

interface AuditEntry {
  id: string
  actor_id: string | null
  action: string
  entity_type: string
  entity_id: string
  created_at: string
}

interface SearchParams {
  entity_type?: string
  entity_id?: string
  limit?: string
  offset?: string
}

async function fetchAudit(
  params: SearchParams,
): Promise<{ entries: AuditEntry[]; total: number }> {
  const cookieStore = await cookies()
  const token = cookieStore.get("access_token")?.value
  if (!token) return { entries: [], total: 0 }

  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL
  if (!apiUrl) return { entries: [], total: 0 }

  const qs = new URLSearchParams()
  if (params.entity_type) qs.set("entity_type", params.entity_type)
  if (params.entity_id) qs.set("entity_id", params.entity_id)
  qs.set("limit", params.limit ?? "25")
  qs.set("offset", params.offset ?? "0")

  try {
    const res = await fetch(`${apiUrl}/api/admin/rbac/audit?${qs.toString()}`, {
      headers: { Cookie: `access_token=${token}` },
      cache: "no-store",
    })
    if (!res.ok) return { entries: [], total: 0 }
    const body = (await res.json()) as { data: { entries: AuditEntry[]; total: number } }
    return { entries: body.data.entries ?? [], total: body.data.total ?? 0 }
  } catch {
    return { entries: [], total: 0 }
  }
}

const ACTION_BADGE: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  "role.create": "default",
  "role.update": "outline",
  "role.disable": "destructive",
  "role.permissions.set": "outline",
  "user.role.assign": "default",
  "user.role.revoke": "destructive",
}

export default async function AuditPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>
}) {
  // Server-side permission check.
  const myPerms = await getMyPermissions()
  if (!myPerms.includes(PERMISSIONS.ADMIN.VIEW_AUDIT_LOG)) {
    notFound()
  }

  const sp = await searchParams
  const { entries, total } = await fetchAudit(sp)
  const limit = Number(sp.limit ?? 25)
  const offset = Number(sp.offset ?? 0)

  return (
    <div className="page-container py-8">
      <div className="page-header">
        <div>
          <h1 className="page-title">Audit Log</h1>
          <p className="text-muted-foreground mt-1">
            All RBAC mutations — role changes, permission updates, and user-role assignments.
          </p>
        </div>
        <Badge variant="outline">{total} total entries</Badge>
      </div>

      <div className="mt-8 table-responsive">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-muted-foreground">
              <th className="pb-2 pr-4 font-medium">When</th>
              <th className="pb-2 pr-4 font-medium">Action</th>
              <th className="pb-2 pr-4 font-medium">Entity</th>
              <th className="pb-2 font-medium">Actor</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((e) => (
              <tr key={e.id} className="border-b border-border last:border-0">
                <td className="py-3 pr-4 text-muted-foreground whitespace-nowrap">
                  {new Date(e.created_at).toLocaleString()}
                </td>
                <td className="py-3 pr-4">
                  <Badge variant={ACTION_BADGE[e.action] ?? "outline"}>{e.action}</Badge>
                </td>
                <td className="py-3 pr-4">
                  <span className="text-muted-foreground">{e.entity_type} / </span>
                  <code className="text-xs">{e.entity_id}</code>
                </td>
                <td className="py-3 text-muted-foreground text-xs">
                  {e.actor_id ? (
                    <code>{e.actor_id}</code>
                  ) : (
                    <span className="italic">system</span>
                  )}
                </td>
              </tr>
            ))}
            {entries.length === 0 && (
              <tr>
                <td colSpan={4} className="py-12 text-center text-muted-foreground">
                  No audit entries found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {total > limit && (
        <div className="mt-6 flex gap-3 justify-end">
          {offset > 0 && (
            <a
              href={`?offset=${Math.max(0, offset - limit)}&limit=${limit}`}
              className="text-sm text-primary underline"
            >
              ← Previous
            </a>
          )}
          {offset + limit < total && (
            <a
              href={`?offset=${offset + limit}&limit=${limit}`}
              className="text-sm text-primary underline"
            >
              Next →
            </a>
          )}
        </div>
      )}
    </div>
  )
}
