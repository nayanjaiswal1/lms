import "server-only";
import { cookies } from "next/headers";
import { apiGet } from "@/lib/server/api";

export interface AuthUser {
  id: string;
  name: string;
  email: string;
  avatar_url: string;
  platform_role: "super_admin" | "user";
}

export interface AuthMeResponse {
  user: AuthUser;
  orgs: { id: string; slug: string; name: string; role: string }[];
  onboarding_completed: boolean;
}

export async function getAuthMe(): Promise<AuthMeResponse | null> {
  try {
    return await apiGet<AuthMeResponse>("/api/auth/me");
  } catch {
    return null;
  }
}

export async function getCurrentUser(): Promise<AuthUser | null> {
  const me = await getAuthMe();
  return me?.user ?? null;
}

/** Reads `org_role` straight off the access token's JWT payload — the same
 * decode-without-verify pattern already used ad hoc across `app/org/settings/*`
 * (the backend has already verified the signature; this is UI-only). Used
 * where a page needs the caller's role in the active org for a client prop
 * (e.g. gating "New Page" / drag-reorder controls in the wiki sidebar). */
export async function getOrgRole(): Promise<string | null> {
  const store = await cookies();
  const token = store.get("access_token")?.value;
  if (!token) return null;
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString()) as { org_role?: string };
    return payload.org_role ?? null;
  } catch {
    return null;
  }
}
