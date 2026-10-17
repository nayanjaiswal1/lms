import "server-only"
import { notFound } from "next/navigation"
import { getBootstrap } from "@/lib/server/bootstrap"

export async function getMyPermissions(): Promise<string[]> {
  return (await getBootstrap()).permissions?.permissions ?? []
}

// Page-level guard: 404 unless the user holds at least one of the codes.
export async function requireAnyPermission(codes: readonly string[]): Promise<void> {
  const held = await getMyPermissions()
  if (!codes.some((c) => held.includes(c))) notFound()
}
