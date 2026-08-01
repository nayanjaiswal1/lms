"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { baseURL, clientIpHeaders } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export async function logoutAction(): Promise<void> {
  const store = await cookies();
  const accessToken = store.get("access_token")?.value ?? "";
  const refreshToken = store.get("refresh_token")?.value ?? "";
  const csrfToken = store.get("csrf_token")?.value ?? "";

  try {
    await fetch(`${baseURL()}/api/auth/logout`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        // eslint-disable-next-line no-restricted-syntax -- authHeaders() deliberately omits refresh_token, but logout is the one call that needs it: the backend revokes the refresh token by looking it up in this cookie. Without it the row stayed valid for the full REFRESH_TOKEN_TTL and only the browser copy was discarded, so a token captured earlier kept working long after the user signed out.
        Cookie: `access_token=${accessToken}; refresh_token=${refreshToken}; csrf_token=${csrfToken}`,
        "X-CSRF-Token": csrfToken,
        ...(await clientIpHeaders()),
      },
      cache: "no-store",
    });
  } catch {
    // Best-effort: clear local cookies even if the backend call fails
  }

  store.delete("access_token");
  store.delete("refresh_token");
  store.delete("csrf_token");

  redirect(ROUTES.LOGIN);
}
