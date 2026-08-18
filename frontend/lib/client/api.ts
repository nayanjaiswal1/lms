// csrf_token is deliberately not httpOnly (double-submit cookie pattern) so
// client components can read and echo it back — see backend RequireCSRF.
export function csrfToken(): string {
  return (
    document.cookie
      .split("; ")
      .find((c) => c.startsWith("csrf_token="))
      ?.slice("csrf_token=".length) ?? ""
  )
}

// Always same-origin (relative /api/...), proxied to the backend by
// next.config.ts's rewrites(). The auth cookie is minted first-party on the
// frontend's own domain (see lib/server/set-cookie.ts), so a client-side
// fetch straight to NEXT_PUBLIC_API_URL is cross-site and never carries it —
// SameSite=Lax silently drops it, producing a 401 with no Cookie header at
// all (see backend/internal/auth/handler.go's cookie config).
export async function apiFetch<T>(path: string, options?: RequestInit): Promise<T | null> {
  try {
    const res = await fetch(`/api${path}`, {
      ...options,
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
        ...(options?.headers ?? {}),
      },
    })
    if (!res.ok) return null
    const body = (await res.json()) as { data: T }
    return body.data
  } catch {
    return null
  }
}
