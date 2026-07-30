"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export async function createRoleAction(input: {
  name: string;
  description?: string;
}): Promise<ActionResult<{ role: { id: string } }>> {
  const result = await apiAction<{ role: { id: string } }>("POST", "/api/admin/rbac/roles", input);
  if (result.ok) revalidatePath(ROUTES.ADMIN_RBAC_ROLES);
  return result;
}

export async function disableRoleAction(roleId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/admin/rbac/roles/${roleId}`);
  if (result.ok) revalidatePath(ROUTES.ADMIN_RBAC_ROLES);
  return result;
}

export async function enableRoleAction(roleId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/admin/rbac/roles/${roleId}/enable`);
  if (result.ok) revalidatePath(ROUTES.ADMIN_RBAC_ROLES);
  return result;
}

// No bulk endpoint exists on the backend, so these fan out over the existing
// single-role endpoints — same permission checks, just N requests instead of one.
export async function bulkDisableRolesAction(roleIds: string[]): Promise<ActionResult<{ failed: number }>> {
  const results = await Promise.all(
    roleIds.map((roleId) => apiAction("DELETE", `/api/admin/rbac/roles/${roleId}`)),
  );
  const failed = results.filter((r) => !r.ok).length;
  if (failed < results.length) revalidatePath(ROUTES.ADMIN_RBAC_ROLES);
  if (failed > 0) return { error: `${failed} of ${roleIds.length} disable(s) failed.`, data: { failed } };
  return { ok: true, data: { failed: 0 } };
}

export async function bulkEnableRolesAction(roleIds: string[]): Promise<ActionResult<{ failed: number }>> {
  const results = await Promise.all(
    roleIds.map((roleId) => apiAction("POST", `/api/admin/rbac/roles/${roleId}/enable`)),
  );
  const failed = results.filter((r) => !r.ok).length;
  if (failed < results.length) revalidatePath(ROUTES.ADMIN_RBAC_ROLES);
  if (failed > 0) return { error: `${failed} of ${roleIds.length} enable(s) failed.`, data: { failed } };
  return { ok: true, data: { failed: 0 } };
}

export async function updateRoleAction(
  roleId: string,
  input: { name: string; description?: string },
): Promise<ActionResult<{ role: { id: string; name: string; description: string } }>> {
  const result = await apiAction<{ role: { id: string; name: string; description: string } }>(
    "PUT",
    `/api/admin/rbac/roles/${roleId}`,
    input,
  );
  if (result.ok) {
    revalidatePath(ROUTES.ADMIN_RBAC_ROLES);
    revalidatePath(`${ROUTES.ADMIN_RBAC_ROLES}/${roleId}`);
  }
  return result;
}
