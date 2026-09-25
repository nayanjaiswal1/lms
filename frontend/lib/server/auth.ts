import "server-only";
import { getBootstrap } from "@/lib/server/bootstrap";
import { getCurrentOrgRole } from "@/lib/server/claims";

export interface AuthUser {
  id: string;
  name: string;
  email: string;
  avatar_url: string;
  platform_role: "super_admin" | "user";
  default_landing_page: string | null;
}

export interface AuthMeResponse {
  user: AuthUser;
  orgs: { id: string; slug: string; name: string; role: string }[];
  onboarding_completed: boolean;
}

export async function getAuthMe(): Promise<AuthMeResponse | null> {
  return (await getBootstrap()).me ?? null;
}

export async function getCurrentUser(): Promise<AuthUser | null> {
  const me = await getAuthMe();
  return me?.user ?? null;
}

/** Reads `org_role` off the access token for UI gating only (e.g. showing the
 * wiki sidebar's "New Page" / drag-reorder controls). Delegates to the shared
 * unverified-claims reader — see lib/server/claims.ts for why reading an
 * unverified JWT is acceptable here and where it is not. */
export async function getOrgRole(): Promise<string | null> {
  return getCurrentOrgRole();
}
