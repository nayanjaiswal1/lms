import "server-only";
import { getBootstrap } from "@/lib/server/bootstrap";

export interface AuthUser {
  id: string;
  name: string;
  email: string;
  avatar_url: string;
  platform_role: "super_admin" | "user";
  default_landing_page: string | null;
  last_page: string | null;
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
