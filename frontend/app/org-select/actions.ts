"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { forwardSetCookies } from "@/lib/server/set-cookie";
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

  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) {
    return { error: "Server configuration error." };
  }

  let response: Response;
  try {
    response = await fetch(`${apiUrl}/api/orgs/switch`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Cookie: `access_token=${accessToken}`,
      },
      body: JSON.stringify({ org_id: orgId }),
      cache: "no-store",
    });
  } catch {
    return { error: "Network error. Please try again." };
  }

  if (!response.ok) {
    const body = await response.json().catch(() => null) as { error?: string } | null;
    return { error: body?.error ?? "Failed to switch organisation." };
  }

  await forwardSetCookies(response.headers);
  redirect(ROUTES.DASHBOARD);
}
