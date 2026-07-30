"use client"

import { useEffect, useState, useCallback } from "react"
import { useParams } from "next/navigation"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { ChecklistGrid } from "@/components/shared/checklist-grid"
import { Breadcrumb } from "@/components/shared/breadcrumb"
import { toast } from "sonner"
import { useHasPermission } from "@/lib/auth/permissions"
import { PERMISSIONS } from "@/lib/auth/permission-codes"
import { apiFetch } from "@/lib/client/api"
import ROUTES from "@/lib/routes"
import { RoleInfoForm } from "./role-info-form"

interface Permission {
  id: string
  code: string
  name: string
  module: string
}

interface Role {
  id: string
  name: string
  description: string
  is_system: boolean
  is_editable: boolean
  is_active: boolean
}

export default function RoleDetailPage() {
  const { id } = useParams<{ id: string }>()
  const canEdit = useHasPermission(PERMISSIONS.ADMIN.MANAGE_PERMISSIONS)
  const canEditRole = useHasPermission(PERMISSIONS.ADMIN.MANAGE_ROLES)

  const [role, setRole] = useState<Role | null>(null)
  const [allPerms, setAllPerms] = useState<Permission[]>([])
  const [assigned, setAssigned] = useState<Set<string>>(new Set())
  const [saving, setSaving] = useState(false)
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    const [roleData, allData, assignedData] = await Promise.all([
      apiFetch<{ role: Role }>(`/admin/rbac/roles/${id}`),
      apiFetch<{ permissions: Permission[] }>(`/admin/rbac/permissions?limit=100`),
      apiFetch<{ permissions: Permission[] }>(`/admin/rbac/roles/${id}/permissions`),
    ])
    if (roleData) setRole(roleData.role)
    if (allData) setAllPerms(allData.permissions)
    if (assignedData) setAssigned(new Set(assignedData.permissions.map((p) => p.id)))
    setLoading(false)
  }, [id])

  useEffect(() => {
    void load()
  }, [load])

  function setAssignedIfEditable(next: Set<string>) {
    if (!canEdit || role?.is_system) return
    setAssigned(next)
  }

  async function save() {
    if (!canEdit) return
    setSaving(true)
    const result = await apiFetch(`/admin/rbac/roles/${id}/permissions`, {
      method: "PUT",
      body: JSON.stringify({ permission_ids: Array.from(assigned) }),
    })
    setSaving(false)
    if (result !== null) {
      toast.success("Permissions saved.")
    } else {
      toast.error("Failed to save permissions.")
    }
  }

  if (loading) {
    return (
      <div className="page-container space-y-4">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-4 w-96" />
        <Skeleton className="h-64 w-full" />
      </div>
    )
  }

  if (!role) {
    return (
      <div className="page-container">
        <p className="text-muted-foreground">Role not found.</p>
      </div>
    )
  }

  const isReadOnly = role.is_system || !role.is_editable || !canEdit

  return (
    <div className="page-container">
      <Breadcrumb items={[{ label: "Roles", href: ROUTES.ADMIN_RBAC_ROLES }, { label: role.name }]} />

      <div className="page-header">
        <RoleInfoForm
          badges={
            <>
              {role.is_system && <Badge variant="outline">System</Badge>}
              {!role.is_active && <Badge variant="secondary">Disabled</Badge>}
            </>
          }
          canEdit={canEditRole && role.is_editable && !role.is_system}
          description={role.description}
          name={role.name}
          roleId={role.id}
          onSaved={(next) => setRole((prev) => (prev ? { ...prev, ...next } : prev))}
        />
        {!isReadOnly && (
          <Button disabled={saving} onClick={save}>
            {saving ? "Saving…" : "Save Permissions"}
          </Button>
        )}
      </div>

      {isReadOnly && (
        <p className="mt-4 text-sm text-muted-foreground">
          {role.is_system
            ? "System roles are read-only. Create a custom role to override permissions."
            : "You need manage_permissions access to edit this role."}
        </p>
      )}

      <div className="mt-8">
        <ChecklistGrid
          disabled={isReadOnly}
          options={allPerms.map((p) => ({ id: p.id, label: p.name, sublabel: p.code, group: p.module }))}
          selected={assigned}
          onChange={setAssignedIfEditable}
        />
      </div>
    </div>
  )
}
