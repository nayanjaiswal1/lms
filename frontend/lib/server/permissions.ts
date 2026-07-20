import "server-only"
import { apiGet } from "@/lib/server/api"

export async function getMyPermissions(): Promise<string[]> {
  try {
    const data = await apiGet<{ permissions: string[] }>("/api/me/permissions")
    return data.permissions ?? []
  } catch {
    return []
  }
}
