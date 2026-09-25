"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { forwardSetCookies } from "@/lib/server/set-cookie";
import { baseURL } from "@/lib/server/api";
import { authFetchWithCookies } from "@/lib/server/auth-fetch";
import ROUTES from "@/lib/routes";

export interface SelectOrgState {
  error?: string;
}

export async function selectOrgAction(
  _prev: SelectOrgState,
  formData: FormData,
): Promise<SelectOrgState> {
  const orgId = formData.get("org_id");
  if (!orgId || typeof orgId !== "string") {
    return { error: "No organisation selected." };
  }

  const cookieStore = await cookies();
  const accessToken = cookieStore.get("access_token")?.value;
  if (!accessToken) {
    redirect(ROUTES.LOGIN);
  }

  try {
    void baseURL();
  } catch {
    return { error: "Server configuration error." };
  }

  // authFetchWithCookies instead of apiAction: this call needs the raw
  // Response so forwardSetCookies() can capture the new Set-Cookie headers
  // the switch endpoint issues — apiAction only reads existing cookies, it
  // never captures Set-Cookie from the response (same pattern as
  // acceptCalendarInviteAction in lib/server/calendar.ts).
  let response: Response;
  let body: { error?: string } | null;
  try {
    const result = await authFetchWithCookies(
      "/api/orgs/switch",
      { org_id: orgId },
      {
        // eslint-disable-next-line no-restricted-syntax -- see comment above; raw Response required for forwardSetCookies.
        headers: { Cookie: `access_token=${accessToken}` },
      },
    );
    response = result.response;
    body = (result.body ?? null) as { error?: string } | null;
  } catch {
    return { error: "Network error. Please try again." };
  }

  if (!response.ok) {
    return { error: body?.error ?? "Failed to switch organisation." };
  }

  await forwardSetCookies(response.headers);
  redirect(ROUTES.DASHBOARD);
}
