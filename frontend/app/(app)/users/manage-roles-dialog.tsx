"use client";

import { useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { useQueryState } from "nuqs";
import { toast } from "sonner";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { MultiSelectDropdown } from "@/components/shared/multi-select-dropdown";
import { useHasPermission } from "@/lib/auth/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { apiFetch, API, csrfToken } from "@/lib/client/api";
import type { OrgRole } from "@/lib/orgs/types";

const ORG_ROLE_OPTIONS: { value: OrgRole; label: string }[] = [
  { value: "owner", label: "Owner" },
  { value: "admin", label: "Admin" },
  { value: "instructor", label: "Instructor" },
  { value: "mentor", label: "Mentor" },
  { value: "learner", label: "Learner" },
];

interface Role {
  id: string;
  name: string;
  description: string;
  is_system: boolean;
  is_active: boolean;
}

interface Permission {
  id: string;
  code: string;
  name: string;
  module: string;
}

interface RolesData {
  assignedRoles: Role[];
  allRoles: Role[];
  effectivePerms: string[];
  allPermissions: Permission[];
  grantedOverrides: Permission[];
}

interface Props {
  userId: string;
  userName: string;
  orgId: string;
  memberId: string;
  /** null when the caller can't see org-membership data (no MANAGE_ORG/VIEW_MEMBERS for this row). */
  orgRole: OrgRole | null;
}

// Opened via the `manageRoles` URL param (set by UserActionsMenu), so only
// one instance needs to be mounted per users table. Covers both role systems
// in one place: the coarse org membership role (owner/admin/instructor/
// mentor/learner) and the granular RBAC roles/permissions below it.
export function ManageRolesDialog({ userId, userName, orgId, memberId, orgRole }: Props) {
  const [openId, setOpenId] = useQueryState("manageRoles");
  const open = openId === userId;
  const canManage = useHasPermission(PERMISSIONS.ADMIN.MANAGE_MEMBERS);
  const canManageOrg = useHasPermission(PERMISSIONS.ADMIN.MANAGE_ORG);
  // Direct permission overrides skip the curation a role provides, so they
  // need both codes — a stricter bar than plain role assignment. Mirrors the
  // backend guard on POST/DELETE .../permission-overrides (routes.go).
  const hasManagePermissions = useHasPermission(PERMISSIONS.ADMIN.MANAGE_PERMISSIONS);
  const canManagePermissions = canManage && hasManagePermissions;
  const router = useRouter();

  const [data, setData] = useState<RolesData | null>(null);
  const [currentOrgRole, setCurrentOrgRole] = useState(orgRole);
  const [isPending, startTransition] = useTransition();

  function updateOrgRole(role: OrgRole) {
    startTransition(async () => {
      const res = await fetch(`${API}/api/orgs/${orgId}/members/${memberId}`, {
        method: "PATCH",
        credentials: "include",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken() },
        body: JSON.stringify({ role }),
      });
      if (res.ok) {
        setCurrentOrgRole(role);
        toast.success("Org role updated.");
        router.refresh();
      } else {
        toast.error("Failed to update org role.");
      }
    });
  }

  async function load() {
    const [userRoles, rolesData, permsData, allPermsData, overridesData] = await Promise.all([
      apiFetch<{ roles: Role[] }>(`/admin/rbac/users/${userId}/roles`),
      apiFetch<{ roles: Role[] }>(`/admin/rbac/roles?limit=100&active=true`),
      apiFetch<{ permissions: string[] }>(`/admin/rbac/users/${userId}/permissions`),
      apiFetch<{ permissions: Permission[] }>(`/admin/rbac/permissions?limit=100`),
      apiFetch<{ permissions: Permission[] }>(`/admin/rbac/users/${userId}/permission-overrides`),
    ]);
    setData({
      assignedRoles: userRoles?.roles ?? [],
      allRoles: rolesData?.roles ?? [],
      effectivePerms: permsData?.permissions ?? [],
      allPermissions: allPermsData?.permissions ?? [],
      grantedOverrides: overridesData?.permissions ?? [],
    });
  }

  // `open` flips to true from outside (the row's "Manage roles" menu item sets
  // the `manageRoles` URL param) rather than via a Radix-owned DialogTrigger,
  // so Radix's onOpenChange never fires to kick off the load — this dialog has
  // no trigger of its own, only a controlled `open` prop.
  useEffect(() => {
    if (open) void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- load() closes over userId, which is stable for this row's dialog instance; only `open` toggling should retrigger the fetch
  }, [open]);

  function assignRole(roleId: string) {
    startTransition(async () => {
      const res = await fetch(`${API}/api/admin/rbac/users/${userId}/roles`, {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken() },
        body: JSON.stringify({ role_id: roleId }),
      });
      if (res.ok) {
        toast.success("Role assigned.");
        await load();
      } else {
        toast.error("Failed to assign role.");
      }
    });
  }

  function revokeRole(roleId: string) {
    startTransition(async () => {
      const res = await fetch(`${API}/api/admin/rbac/users/${userId}/roles/${roleId}`, {
        method: "DELETE",
        credentials: "include",
        headers: { "X-CSRF-Token": csrfToken() },
      });
      if (res.ok) {
        toast.success("Role revoked.");
        await load();
      } else {
        toast.error("Failed to revoke role.");
      }
    });
  }

  function toggleRole(roleId: string) {
    const isAssigned = data?.assignedRoles.some((r) => r.id === roleId) ?? false;
    if (isAssigned) revokeRole(roleId);
    else assignRole(roleId);
  }

  function grantPermission(permissionId: string) {
    startTransition(async () => {
      const res = await fetch(`${API}/api/admin/rbac/users/${userId}/permission-overrides`, {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken() },
        body: JSON.stringify({ permission_id: permissionId }),
      });
      if (res.ok) {
        toast.success("Permission granted.");
        await load();
      } else {
        toast.error("Failed to grant permission.");
      }
    });
  }

  function revokePermission(permissionId: string) {
    startTransition(async () => {
      const res = await fetch(`${API}/api/admin/rbac/users/${userId}/permission-overrides/${permissionId}`, {
        method: "DELETE",
        credentials: "include",
        headers: { "X-CSRF-Token": csrfToken() },
      });
      if (res.ok) {
        toast.success("Permission revoked.");
        await load();
      } else {
        toast.error("Failed to revoke permission.");
      }
    });
  }

  function togglePermission(permissionId: string) {
    const isGranted = data?.grantedOverrides.some((p) => p.id === permissionId) ?? false;
    if (isGranted) revokePermission(permissionId);
    else grantPermission(permissionId);
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => void setOpenId(next ? userId : null)}
    >
      <DialogContent className="modal-responsive overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Manage roles — {userName}</DialogTitle>
        </DialogHeader>

        {data === null ? (
          <div className="space-y-4">
            <Skeleton className="h-24 w-full" />
            <Skeleton className="h-32 w-full" />
          </div>
        ) : (
          <>
            {currentOrgRole && (
              <section>
                <h3 className="text-sm font-semibold mb-2">Organization role</h3>
                {canManageOrg ? (
                  <Select
                    disabled={isPending}
                    value={currentOrgRole}
                    onValueChange={(v) => updateOrgRole(v as OrgRole)}
                  >
                    <SelectTrigger aria-label={`Change org role for ${userName}`} className="h-9 w-48">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {ORG_ROLE_OPTIONS.map((opt) => (
                        <SelectItem key={opt.value} value={opt.value}>
                          {opt.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                ) : (
                  <Badge variant="outline">{currentOrgRole}</Badge>
                )}
              </section>
            )}

            <section className="mt-4">
              <h3 className="text-sm font-semibold mb-2">RBAC roles</h3>
              <MultiSelectDropdown
                disabled={!canManage || isPending}
                options={data.allRoles.map((r) => ({ id: r.id, label: r.name }))}
                placeholder="Search roles…"
                selected={new Set(data.assignedRoles.map((r) => r.id))}
                onToggle={toggleRole}
              />
            </section>

            {canManagePermissions && (
              <section className="mt-4">
                <h3 className="text-sm font-semibold mb-2">Custom permissions</h3>
                <MultiSelectDropdown
                  disabled={isPending}
                  options={data.allPermissions.map((p) => ({
                    id: p.id,
                    label: p.name,
                    sublabel: p.code,
                    group: p.module,
                  }))}
                  placeholder="Search permissions…"
                  selected={new Set(data.grantedOverrides.map((p) => p.id))}
                  onToggle={togglePermission}
                />
              </section>
            )}

            <section className="mt-4">
              <h3 className="text-sm font-semibold mb-2">
                Effective permissions{" "}
                <Badge className="ml-2" variant="secondary">
                  {data.effectivePerms.length}
                </Badge>
              </h3>
              {data.effectivePerms.length === 0 ? (
                <p className="text-muted-foreground text-sm">No effective permissions.</p>
              ) : (
                <div className="flex flex-wrap gap-2">
                  {data.effectivePerms.sort().map((code) => (
                    <code className="kbd text-xs" key={code}>
                      {code}
                    </code>
                  ))}
                </div>
              )}
            </section>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
