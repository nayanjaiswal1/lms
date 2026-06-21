import "server-only";
import { cookies } from "next/headers";

export interface AuthUser {
  id: string;
  name: string;
  email: string;
  avatar_url: string;
}

export async function getCurrentUser(): Promise<AuthUser | null> {
  const cookieStore = await cookies();
  const accessToken = cookieStore.get("access_token")?.value;
  if (!accessToken) return null;

  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) return null;

  try {
    const res = await fetch(`${apiUrl}/api/auth/me`, {
      headers: { Cookie: `access_token=${accessToken}` },
      cache: "no-store",
    });
    if (!res.ok) return null;
    const body: { data: { user: AuthUser } } = await res.json();
    return body.data.user;
  } catch {
    return null;
  }
}
