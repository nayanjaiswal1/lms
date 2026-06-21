"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { toast } from "sonner"
import ROUTES from "@/lib/routes"

const API = process.env.NEXT_PUBLIC_API_URL ?? ""

export default function NewRolePage() {
  const router = useRouter()
  const [name, setName] = useState("")
  const [description, setDescription] = useState("")
  const [saving, setSaving] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!name.trim()) return

    setSaving(true)
    const res = await fetch(`${API}/api/admin/rbac/roles`, {
      method: "POST",
      credentials: "include",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: name.trim(), description: description.trim() }),
    })
    setSaving(false)

    if (!res.ok) {
      const body = (await res.json().catch(() => null)) as { error?: string } | null
      toast.error(body?.error ?? "Failed to create role.")
      return
    }

    const body = (await res.json()) as { data: { role: { id: string } } }
    toast.success("Role created.")
    router.push(`${ROUTES.ADMIN_RBAC_ROLES}/${body.data.role.id}`)
  }

  return (
    <div className="page-container py-8">
      <div className="page-header">
        <div>
          <h1 className="page-title">New Role</h1>
          <p className="text-muted-foreground mt-1">
            Create a custom role for your organisation. Assign permissions after creation.
          </p>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="mt-8 max-w-lg form-stack">
        <div className="flex flex-col gap-2">
          <Label htmlFor="name">Role name</Label>
          <Input
            id="name"
            placeholder="e.g. content-reviewer"
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
            maxLength={80}
          />
        </div>

        <div className="flex flex-col gap-2">
          <Label htmlFor="description">Description</Label>
          <Textarea
            id="description"
            placeholder="What is this role for?"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={3}
            maxLength={255}
          />
        </div>

        <div className="flex gap-3 pt-2">
          <Button type="submit" disabled={saving || !name.trim()}>
            {saving ? "Creating…" : "Create Role"}
          </Button>
          <Button
            type="button"
            variant="ghost"
            onClick={() => router.push(ROUTES.ADMIN_RBAC_ROLES)}
          >
            Cancel
          </Button>
        </div>
      </form>
    </div>
  )
}
