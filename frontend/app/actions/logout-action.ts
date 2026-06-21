"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { authHeaders, baseURL } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export async function logoutAction(): Promise<void> {
  try {
    await fetch(`${baseURL()}/api/auth/logout`, {
      method: "POST",
      headers: await authHeaders(),
      cache: "no-store",
    });
  } catch {
    // Best-effort: clear local cookies even if the backend call fails
  }

  const store = await cookies();
  store.delete("access_token");
  store.delete("refresh_token");
  store.delete("csrf_token");

  redirect(ROUTES.LOGIN);
}
