import { notFound, redirect } from "next/navigation"
import { Badge } from "@/components/ui/badge"
import { Breadcrumb } from "@/components/shared/breadcrumb"
import { getMyPermissions } from "@/lib/server/permissions"
import { apiGet } from "@/lib/server/api"
import { getCurrentOrgId } from "@/lib/server/claims"
import { PERMISSIONS } from "@/lib/auth/permission-codes"
import ROUTES from "@/lib/routes"
import { RoleBadges } from "@/app/(app)/users/role-badges"
import { UserActionsMenu } from "@/app/(app)/users/user-actions-menu"
import { ManageRolesDialog } from "@/app/(app)/users/manage-roles-dialog"
import { ManageFeaturesDialog } from "@/app/(app)/users/manage-features-dialog"
import { UserDetailTabs } from "@/app/(app)/users/[id]/user-detail-tabs"
import { OverviewTab } from "@/app/(app)/users/[id]/overview-tab"
import { CoursesTab } from "@/app/(app)/users/[id]/courses-tab"
import { SheetsTab } from "@/app/(app)/users/[id]/sheets-tab"
import { MistakesTab } from "@/app/(app)/users/[id]/mistakes-tab"
import { HabitsTab } from "@/app/(app)/users/[id]/habits-tab"
import { JournalTab } from "@/app/(app)/users/[id]/journal-tab"
import { AccessTab } from "@/app/(app)/users/[id]/access-tab"
import { AuditTab } from "@/app/(app)/users/[id]/audit-tab"
import type { AuditEntry, PermissionMeta, RoleFull, UserOverview } from "@/app/(app)/users/[id]/types"
import type { OrgRole } from "@/lib/orgs/types"

interface UserDetail {
  id: string
  member_id: string
  name: string
  email: string
  avatar_url: string | null
  org_role: OrgRole
  role_names: string[]
  status: string
  account_status: string
  joined_at: string
}

function orgRoleBadgeClass(role: string): string {
  switch (role) {
    case "owner": return "bg-primary text-primary-foreground"
    case "admin": return "bg-muted text-foreground"
    default:      return "bg-muted text-muted-foreground"
  }
}

interface PageProps {
  params: Promise<{ id: string }>
}

export default async function UserDetailPage({ params }: PageProps) {
  const { id } = await params

  const myPerms = await getMyPermissions()
  const canView = myPerms.includes(PERMISSIONS.ADMIN.VIEW_MEMBERS) || myPerms.includes(PERMISSIONS.ADMIN.MANAGE_MEMBERS)
  if (!canView) notFound()

  const orgId = await getCurrentOrgId()
  if (!orgId) redirect(ROUTES.ORG_SELECT)

  const [user, overview, rolesData, permsData, overridesData, auditData] = await Promise.all([
    apiGet<UserDetail>(`/api/admin/rbac/users/${id}`),
    apiGet<UserOverview>(`/api/admin/rbac/users/${id}/overview`),
    apiGet<{ roles: RoleFull[] }>(`/api/admin/rbac/users/${id}/roles`),
    apiGet<{ permissions: string[] }>(`/api/admin/rbac/users/${id}/permissions`),
    apiGet<{ permissions: PermissionMeta[] }>(`/api/admin/rbac/users/${id}/permission-overrides`),
    apiGet<{ entries: AuditEntry[] }>(`/api/admin/rbac/audit?entity_id=${id}&limit=25`),
  ])

  const roles = rolesData.roles ?? []

  const tabs = [
    { value: "overview" as const, label: "Overview", content: <OverviewTab overview={overview} roleCount={roles.length} /> },
    { value: "courses" as const, label: "Courses", content: <CoursesTab enrollments={overview.enrollments} /> },
    { value: "sheets" as const, label: "Sheets", content: <SheetsTab sheets={overview.sheets} /> },
    { value: "mistakes" as const, label: "Mistakes", content: <MistakesTab entries={overview.mistakes} summary={overview.mistake_summary} /> },
    { value: "habits" as const, label: "Habits", content: <HabitsTab habitMonth={overview.habit_month} /> },
    { value: "journal" as const, label: "Journal", content: <JournalTab entries={overview.journal_entries} /> },
    {
      value: "access" as const,
      label: "Access",
      content: (
        <AccessTab
          effectivePermissions={permsData.permissions ?? []}
          overrides={overridesData.permissions ?? []}
          roles={roles}
        />
      ),
    },
    { value: "audit" as const, label: "Audit Log", content: <AuditTab entries={auditData.entries ?? []} /> },
  ]

  return (
    <div className="page-container">
      <Breadcrumb items={[{ label: "Users", href: ROUTES.USERS }, { label: user.name }]} />

      <div className="page-header">
        <div className="flex items-center gap-4 min-w-0">
          <div className="h-14 w-14 shrink-0 rounded-full bg-muted flex items-center justify-center text-lg font-medium text-foreground overflow-hidden">
            {user.avatar_url ? (
              /* eslint-disable-next-line @next/next/no-img-element */
              <img alt={user.name} className="h-14 w-14 rounded-full object-cover" src={user.avatar_url} />
            ) : (
              user.name.charAt(0).toUpperCase()
            )}
          </div>
          <div className="min-w-0">
            <h1 className="page-title truncate">{user.name}</h1>
            <p className="text-muted-foreground mt-1 truncate">{user.email}</p>
          </div>
        </div>

        <div className="flex items-center gap-1">
          <ManageFeaturesDialog orgId={orgId} userId={user.id} userName={user.name} />
          <UserActionsMenu
            accountStatus={user.account_status}
            email={user.email}
            memberId={user.member_id}
            name={user.name}
            orgId={orgId}
            status={user.status}
            userId={user.id}
          />
          <ManageRolesDialog
            memberId={user.member_id}
            orgId={orgId}
            orgRole={user.org_role}
            userId={user.id}
            userName={user.name}
          />
        </div>
      </div>

      <div className="mt-8 card-base p-6">
        <div className="flex flex-wrap items-center gap-3">
          <Badge className={orgRoleBadgeClass(user.org_role)} variant="outline">
            {user.org_role}
          </Badge>
          <RoleBadges roleNames={user.role_names} />

          {user.status !== "active" && (
            <Badge variant={user.status === "suspended" ? "destructive" : "secondary"}>
              org: {user.status}
            </Badge>
          )}
          {user.account_status !== "active" && (
            <Badge variant="destructive">account: {user.account_status}</Badge>
          )}

          <span className="ml-auto text-sm text-muted-foreground">
            Joined {new Date(user.joined_at).toLocaleDateString()}
          </span>
        </div>
      </div>

      <UserDetailTabs tabs={tabs} />
    </div>
  )
}
