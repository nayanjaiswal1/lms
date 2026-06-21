"use client"

import { useEffect, useState, useCallback } from "react"
import { useParams } from "next/navigation"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { toast } from "sonner"
import { useHasPermission } from "@/lib/auth/permissions"
import { PERMISSIONS } from "@/lib/auth/permission-codes"

interface Role {
  id: string
  name: string
  description: string
  is_system: boolean
  is_active: boolean
}

const API = process.env.NEXT_PUBLIC_API_URL ?? ""

async function apiFetch<T>(path: string, options?: RequestInit): Promise<T | null> {
  try {
    const res = await fetch(`${API}/api${path}`, {
      ...options,
      credentials: "include",
      headers: { "Content-Type": "application/json", ...(options?.headers ?? {}) },
    })
    if (!res.ok) return null
    const body = (await res.json()) as { data: T }
    return body.data
  } catch {
    return null
  }
}

export default function UserRolesPage() {
  const { userId } = useParams<{ userId: string }>()
  const canManage = useHasPermission(PERMISSIONS.ADMIN.MANAGE_MEMBERS)

  const [assignedRoles, setAssignedRoles] = useState<Role[]>([])
  const [allRoles, setAllRoles] = useState<Role[]>([])
  const [effectivePerms, setEffectivePerms] = useState<string[]>([])
  const [selectedRoleID, setSelectedRoleID] = useState("")
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    const [userRoles, rolesData, permsData] = await Promise.all([
      apiFetch<{ roles: Role[] }>(`/admin/rbac/users/${userId}/roles`),
      apiFetch<{ roles: Role[] }>(`/admin/rbac/roles?limit=100&active=true`),
      apiFetch<{ permissions: string[] }>(`/admin/rbac/users/${userId}/permissions`),
    ])
    if (userRoles) setAssignedRoles(userRoles.roles)
    if (rolesData) setAllRoles(rolesData.roles)
    if (permsData) setEffectivePerms(permsData.permissions)
    setLoading(false)
  }, [userId])

  useEffect(() => {
    void load()
  }, [load])

  async function assignRole() {
    if (!selectedRoleID) return
    const res = await fetch(`${API}/api/admin/rbac/users/${userId}/roles`, {
      method: "POST",
      credentials: "include",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ role_id: selectedRoleID }),
    })
    if (res.ok) {
      toast.success("Role assigned.")
      setSelectedRoleID("")
      await load()
    } else {
      toast.error("Failed to assign role.")
    }
  }

  async function revokeRole(roleID: string) {
    const res = await fetch(`${API}/api/admin/rbac/users/${userId}/roles/${roleID}`, {
      method: "DELETE",
      credentials: "include",
    })
    if (res.ok) {
      toast.success("Role revoked.")
      await load()
    } else {
      toast.error("Failed to revoke role.")
    }
  }

  const unassignedRoles = allRoles.filter(
    (r) => !assignedRoles.some((a) => a.id === r.id),
  )

  if (loading) {
    return (
      <div className="page-container py-8 space-y-4">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-32 w-full" />
        <Skeleton className="h-48 w-full" />
      </div>
    )
  }

  return (
    <div className="page-container py-8">
      <div className="page-header">
        <div>
          <h1 className="page-title">User Roles</h1>
          <p className="text-muted-foreground mt-1">
            Manage role assignments for this user.
          </p>
        </div>
      </div>

      <section className="mt-8">
        <h2 className="section-title mb-4">Assigned Roles</h2>
        {assignedRoles.length === 0 ? (
          <p className="text-muted-foreground text-sm">No roles assigned yet.</p>
        ) : (
          <div className="space-y-2">
            {assignedRoles.map((role) => (
              <div
                key={role.id}
                className="flex items-center justify-between rounded-lg border border-border p-3"
              >
                <div>
                  <span className="font-medium">{role.name}</span>
                  {role.is_system && (
                    <Badge variant="outline" className="ml-2 text-xs">
                      System
                    </Badge>
                  )}
                </div>
                {canManage && (
                  <Button variant="ghost" size="sm" onClick={() => revokeRole(role.id)}>
                    Revoke
                  </Button>
                )}
              </div>
            ))}
          </div>
        )}
      </section>

      {canManage && unassignedRoles.length > 0 && (
        <section className="mt-8">
          <h2 className="section-title mb-4">Assign Role</h2>
          <div className="flex gap-3 items-center">
            <Select value={selectedRoleID} onValueChange={setSelectedRoleID}>
              <SelectTrigger className="w-64">
                <SelectValue placeholder="Select a role…" />
              </SelectTrigger>
              <SelectContent>
                {unassignedRoles.map((r) => (
                  <SelectItem key={r.id} value={r.id}>
                    {r.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Button onClick={assignRole} disabled={!selectedRoleID}>
              Assign
            </Button>
          </div>
        </section>
      )}

      <section className="mt-8">
        <h2 className="section-title mb-4">
          Effective Permissions{" "}
          <Badge variant="secondary" className="ml-2">
            {effectivePerms.length}
          </Badge>
        </h2>
        {effectivePerms.length === 0 ? (
          <p className="text-muted-foreground text-sm">No effective permissions.</p>
        ) : (
          <div className="flex flex-wrap gap-2">
            {effectivePerms.sort().map((code) => (
              <code key={code} className="kbd text-xs">
                {code}
              </code>
            ))}
          </div>
        )}
      </section>
    </div>
  )
}
