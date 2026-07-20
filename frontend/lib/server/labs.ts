import "server-only";
import { apiGet } from "@/lib/server/api";
import type { ActiveLabSession, GetSessionResponse, Lab } from "@/lib/labs";

/**
 * The user's single active lab session (provisioning/running/paused), if any.
 * Fetched once in the root layout so a lab survives a page refresh or a fresh
 * login instead of only living in client-side React state. Never throws —
 * root layout renders for logged-out routes too, so a missing token or a
 * backend hiccup here must not break the whole app shell.
 */
export async function getActiveLabSession(): Promise<ActiveLabSession | null> {
  try {
    const sessions = await apiGet<ActiveLabSession[]>("/api/labs/sessions/active");
    return sessions?.[0] ?? null;
  } catch {
    return null;
  }
}

/**
 * The lab attached to a "notes" module, if any, plus the caller's in-progress
 * session for it. Returns null when the module has no attached lab.
 */
export async function getModuleLab(
  moduleId: string,
): Promise<{ lab: Lab; initialSession: GetSessionResponse | null } | null> {
  let lab: Lab;
  try {
    lab = await apiGet<Lab>(`/api/modules/${moduleId}/lab`);
  } catch {
    return null;
  }

  const active = await getActiveLabSession();
  const initialSession =
    active && active.lab_id === lab.id
      ? await apiGet<GetSessionResponse>(`/api/labs/sessions/${active.session_id}`).catch(() => null)
      : null;

  return { lab, initialSession };
}
