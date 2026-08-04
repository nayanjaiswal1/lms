"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import { apiGet, apiAction, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export async function exportMyDataAction(): Promise<ActionResult<Record<string, unknown>>> {
  try {
    const data = await apiGet<Record<string, unknown>>("/api/privacy/export");
    return { ok: true, data };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Could not export your data." };
  }
}

// Mirrors app/actions/logout-action.ts's cookie-clearing — deletion already
// killed the session server-side (session_version bump), this just drops
// the now-invalid cookies from the browser too.
export async function deleteMyAccountAction(password: string): Promise<ActionResult> {
  const result = await apiAction("POST", "/api/privacy/delete-account", { password });
  if (result.error) return result;

  const store = await cookies();
  store.delete("access_token");
  store.delete("refresh_token");
  store.delete("csrf_token");

  redirect(ROUTES.HOME);
}
