import "server-only";
import { cookies } from "next/headers";
import type { ActiveLabSession } from "@/lib/labs";

/**
 * The user's single active lab session (provisioning/running/paused), if any.
 * Fetched once in the root layout so a lab survives a page refresh or a fresh
 * login instead of only living in client-side React state. Never throws —
 * root layout renders for logged-out routes too, so a missing token or a
 * backend hiccup here must not break the whole app shell.
 */
export async function getActiveLabSession(): Promise<ActiveLabSession | null> {
  const cookieStore = await cookies();
  const token = cookieStore.get("access_token")?.value;
  if (!token) return null;

  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) return null;

  try {
    const res = await fetch(`${apiUrl}/api/labs/sessions/active`, {
      headers: { Cookie: `access_token=${token}` },
      cache: "no-store",
    });
    if (!res.ok) return null;
    const body = (await res.json()) as { data: ActiveLabSession[] };
    return body.data?.[0] ?? null;
  } catch {
    return null;
  }
}
