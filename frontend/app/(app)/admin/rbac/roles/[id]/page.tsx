"use client"

import { useEffect, useState, useCallback } from "react"
import { useParams } from "next/navigation"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { toast } from "sonner"
import { useHasPermission } from "@/lib/auth/permissions"
import { PERMISSIONS } from "@/lib/auth/permission-codes"

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

function groupByModule(perms: Permission[]): Record<string, Permission[]> {
  return perms.reduce<Record<string, Permission[]>>((acc, p) => {
    if (!acc[p.module]) acc[p.module] = []
    acc[p.module].push(p)
    return acc
  }, {})
}

export default function RoleDetailPage() {
  const { id } = useParams<{ id: string }>()
  const canEdit = useHasPermission(PERMISSIONS.ADMIN.MANAGE_PERMISSIONS)

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

  function toggle(permID: string) {
    if (!canEdit || role?.is_system) return
    setAssigned((prev) => {
      const next = new Set(prev)
      if (next.has(permID)) next.delete(permID)
      else next.add(permID)
      return next
    })
  }

  async function save() {
    if (!canEdit) return
    setSaving(true)
    const res = await fetch(`${API}/api/admin/rbac/roles/${id}/permissions`, {
      method: "PUT",
      credentials: "include",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ permission_ids: Array.from(assigned) }),
    })
    setSaving(false)
    if (res.ok) {
      toast.success("Permissions saved.")
    } else {
      toast.error("Failed to save permissions.")
    }
  }

  if (loading) {
    return (
      <div className="page-container py-8 space-y-4">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-4 w-96" />
        <Skeleton className="h-64 w-full" />
      </div>
    )
  }

  if (!role) {
    return (
      <div className="page-container py-8">
        <p className="text-muted-foreground">Role not found.</p>
      </div>
    )
  }

  const grouped = groupByModule(allPerms)
  const modules = Object.keys(grouped).sort()
  const isReadOnly = role.is_system || !role.is_editable || !canEdit

  return (
    <div className="page-container py-8">
      <div className="page-header">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="page-title">{role.name}</h1>
            {role.is_system && <Badge variant="outline">System</Badge>}
            {!role.is_active && <Badge variant="secondary">Disabled</Badge>}
          </div>
          <p className="text-muted-foreground mt-1">{role.description}</p>
        </div>
        {!isReadOnly && (
          <Button onClick={save} disabled={saving}>
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

      <div className="mt-8 space-y-8">
        {modules.map((module) => (
          <section key={module}>
            <h2 className="section-title capitalize mb-4">{module}</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
              {grouped[module].map((p) => {
                const checked = assigned.has(p.id)
                return (
                  <label
                    key={p.id}
                    className={`flex items-start gap-3 rounded-lg border p-3 transition-colors ${
                      isReadOnly ? "cursor-default" : "cursor-pointer hover:bg-muted/50"
                    } ${checked ? "border-primary bg-primary/5" : "border-border"}`}
                  >
                    <input
                      type="checkbox"
                      checked={checked}
                      onChange={() => toggle(p.id)}
                      disabled={isReadOnly}
                      className="mt-0.5 accent-primary"
                    />
                    <div>
                      <p className="font-medium text-sm">{p.name}</p>
                      <code className="text-xs text-muted-foreground">{p.code}</code>
                    </div>
                  </label>
                )
              })}
            </div>
          </section>
        ))}
      </div>
    </div>
  )
}
