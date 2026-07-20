import "server-only";
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
