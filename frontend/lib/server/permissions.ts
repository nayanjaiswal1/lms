import "server-only"
import { getBootstrap } from "@/lib/server/bootstrap"

export async function getMyPermissions(): Promise<string[]> {
  return (await getBootstrap()).permissions?.permissions ?? []
}
