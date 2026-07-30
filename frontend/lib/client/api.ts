export const API = process.env.NEXT_PUBLIC_API_URL ?? ""

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

export async function apiFetch<T>(path: string, options?: RequestInit): Promise<T | null> {
  try {
    const res = await fetch(`${API}/api${path}`, {
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
