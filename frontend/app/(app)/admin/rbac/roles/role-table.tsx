"use client";

import { Fragment, useState } from "react";
import Link from "next/link";
import { parseAsStringLiteral, useQueryState } from "nuqs";
import { Lock, UserCog, Eye, GraduationCap, Handshake, Crown, type LucideIcon } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";
import { Skeleton } from "@/components/ui/skeleton";
import { Collapsible, CollapsibleContent } from "@/components/ui/collapsible";
import { getModuleIcon } from "@/components/shared/checklist-grid";
import { useRowSelection } from "@/hooks/use-row-selection";
import { apiFetch } from "@/lib/client/api";
import { RoleActionsMenu } from "./role-actions-menu";
import { RoleBulkActions } from "./role-bulk-actions";
import { ROLE_TYPE_FILTERS, ROLE_STATUS_FILTERS } from "./role-filters";

// Fixed system-role name → icon (see docs/rbac.md § System Roles). Custom
// (org-created) roles have no fixed identity, so they all share UserCog;
// an unrecognised system role name falls back to Lock.
const SYSTEM_ROLE_ICONS: Record<string, LucideIcon> = {
  viewer: Eye,
  member: GraduationCap,
  instructor: GraduationCap,
  mentor: Handshake,
  tenant_admin: Crown,
};

function getRoleIcon(role: Role): LucideIcon {
  if (!role.is_system) return UserCog;
  return SYSTEM_ROLE_ICONS[role.name] ?? Lock;
}

export interface Role {
  id: string;
  name: string;
  description: string;
  is_system: boolean;
  is_editable: boolean;
  is_active: boolean;
  tenant_id: string | null;
}

interface Permission {
  id: string;
  code: string;
  name: string;
  module: string;
}

type PermState = Permission[] | "loading" | "error";

export function RoleTable({ roles }: { roles: Role[] }) {
  const [expanded, setExpanded] = useState<string | null>(null);
  const [permsByRole, setPermsByRole] = useState<Record<string, PermState>>({});

  const [search] = useQueryState("search", { defaultValue: "" });
  const [type] = useQueryState("type", parseAsStringLiteral(ROLE_TYPE_FILTERS).withDefault("all"));
  const [status] = useQueryState("status", parseAsStringLiteral(ROLE_STATUS_FILTERS).withDefault("all"));

  const query = search.trim().toLowerCase();
  const filtered = roles.filter((role) => {
    if (type === "system" && !role.is_system) return false;
    if (type === "custom" && role.is_system) return false;
    if (status === "active" && !role.is_active) return false;
    if (status === "disabled" && role.is_active) return false;
    if (query && !role.name.toLowerCase().includes(query) && !role.description.toLowerCase().includes(query)) {
      return false;
    }
    return true;
  });

  async function toggleRow(roleId: string) {
    if (expanded === roleId) {
      setExpanded(null);
      return;
    }
    setExpanded(roleId);
    if (permsByRole[roleId]) return;
    setPermsByRole((prev) => ({ ...prev, [roleId]: "loading" }));
    const data = await apiFetch<{ permissions: Permission[] }>(`/admin/rbac/roles/${roleId}/permissions`);
    setPermsByRole((prev) => ({ ...prev, [roleId]: data ? data.permissions : "error" }));
  }

  // System roles have no bulk action (mirrors RoleActionsMenu, which never
  // renders for them) — any custom role is selectable, active or not, since
  // role-bulk-actions.tsx offers Enable and Disable as separate actions.
  const selectableIds = filtered.filter((r) => !r.is_system).map((r) => r.id);
  const selection = useRowSelection(selectableIds);
  const selectedRoles = filtered
    .filter((r) => selection.isSelected(r.id))
    .map((r) => ({ id: r.id, isActive: r.is_active }));

  if (filtered.length === 0) {
    return (
      <div className="empty-state">
        <p className="text-muted-foreground">No roles match these filters.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-muted-foreground">
        {filtered.length} of {roles.length} {roles.length === 1 ? "role" : "roles"}
      </p>
      <RoleBulkActions roles={selectedRoles} onDone={selection.clear} />
      <div className="table-responsive">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-muted-foreground">
              <th className="w-8 pb-2 pr-3">
                <Checkbox
                  aria-label="Select all roles"
                  checked={selection.allSelected ? true : selection.someSelected ? "indeterminate" : false}
                  disabled={selectableIds.length === 0}
                  onCheckedChange={selection.toggleAll}
                />
              </th>
              <th className="pb-2 pr-6 font-medium">Name</th>
              <th className="pb-2 pr-6 font-medium">Description</th>
              <th className="pb-2 pr-6 font-medium">Type</th>
              <th className="pb-2 pr-6 font-medium">Status</th>
              <th className="pb-2 font-medium" />
            </tr>
          </thead>
          <tbody>
            {filtered.map((role) => {
              const isOpen = expanded === role.id;
              const perms = permsByRole[role.id];
              const RoleIcon = getRoleIcon(role);
              const isSelectable = !role.is_system;
              return (
                <Fragment key={role.id}>
                  <tr
                    className="cursor-pointer border-b border-border transition-colors last:border-0 hover:bg-muted/50"
                    onClick={() => void toggleRow(role.id)}
                  >
                    <td className="py-3 pr-3" onClick={(e) => e.stopPropagation()}>
                      <Checkbox
                        aria-label={`Select ${role.name}`}
                        checked={selection.isSelected(role.id)}
                        disabled={!isSelectable}
                        onCheckedChange={() => selection.toggle(role.id)}
                      />
                    </td>
                    <td className="py-3 pr-6 font-medium">
                      <Link
                        className="inline-flex items-center gap-1.5 hover:underline"
                        href={`/admin/rbac/roles/${role.id}`}
                        onClick={(e) => e.stopPropagation()}
                      >
                        <RoleIcon aria-hidden className="h-4 w-4 text-muted-foreground" />
                        {role.name}
                      </Link>
                    </td>
                    <td className="py-3 pr-6 text-muted-foreground">{role.description}</td>
                    <td className="py-3 pr-6 text-muted-foreground">{role.is_system ? "System" : "Custom"}</td>
                    <td className="py-3 pr-6">
                      {role.is_active ? (
                        <Badge variant="default">Active</Badge>
                      ) : (
                        <Badge variant="secondary">Disabled</Badge>
                      )}
                    </td>
                    <td className="py-3 text-right" onClick={(e) => e.stopPropagation()}>
                      {role.is_system ? (
                        // Same footprint as the button below (.touch-target on both) so a
                        // system row's action cell doesn't collapse shorter than a custom
                        // row's — the row's height should never depend on which role type it is.
                        <div aria-hidden className="touch-target ml-auto" />
                      ) : (
                        <RoleActionsMenu isActive={role.is_active} roleId={role.id} roleName={role.name} />
                      )}
                    </td>
                  </tr>
                  <tr className="last:border-0">
                    <td className="p-0" colSpan={6}>
                      <Collapsible open={isOpen} onOpenChange={() => toggleRow(role.id)}>
                        <CollapsibleContent className="border-b border-border bg-muted/30">
                          <div className="px-8 py-4">
                            {perms === "loading" && <Skeleton className="h-16 w-full" />}
                            {perms === "error" && (
                              <p className="text-sm text-destructive">Failed to load permissions.</p>
                            )}
                            {Array.isArray(perms) && <PermissionSummary permissions={perms} />}
                          </div>
                        </CollapsibleContent>
                      </Collapsible>
                    </td>
                  </tr>
                </Fragment>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}

// Permission codes are "<resource>.<action>" (e.g. "courses.create") and the
// resource always matches the module — so one line per module, actions
// comma-joined, replaces what would otherwise be a full row per permission.
function actionLabel(code: string): string {
  const action = code.split(".")[1] ?? code;
  return action.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

function PermissionSummary({ permissions }: { permissions: Permission[] }) {
  if (permissions.length === 0) {
    return <p className="text-sm text-muted-foreground">No permissions assigned.</p>;
  }

  const grouped = permissions.reduce<Record<string, Permission[]>>((acc, p) => {
    (acc[p.module] ??= []).push(p);
    return acc;
  }, {});
  const modules = Object.keys(grouped).sort();

  return (
    <ul className="rounded-sm border border-border bg-card divide-y divide-border">
      {modules.map((module) => {
        const ModuleIcon = getModuleIcon(module);
        const actions = grouped[module].map((p) => actionLabel(p.code)).join(", ");
        return (
          <li className="flex items-start gap-3 px-4 py-2.5" key={module}>
            <ModuleIcon aria-hidden className="mt-0.5 h-4 w-4 shrink-0 text-muted-foreground" />
            <p className="min-w-0 text-sm leading-relaxed">
              <span className="font-medium capitalize">{module}</span>
              <span className="text-muted-foreground"> — {actions}</span>
            </p>
          </li>
        );
      })}
    </ul>
  );
}
