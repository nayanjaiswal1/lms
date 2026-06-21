import "server-only"
import { cookies } from "next/headers"

export async function getMyPermissions(): Promise<string[]> {
  const cookieStore = await cookies()
  const accessToken = cookieStore.get("access_token")?.value
  if (!accessToken) return []

  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL
  if (!apiUrl) return []

  try {
    const res = await fetch(`${apiUrl}/api/me/permissions`, {
      headers: { Cookie: `access_token=${accessToken}` },
      cache: "no-store",
    })
    if (!res.ok) return []
    const body = (await res.json()) as { data: { permissions: string[] } }
    return body.data.permissions ?? []
  } catch {
    return []
  }
}
