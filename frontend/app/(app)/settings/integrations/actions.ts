"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export async function revokeMcpConnectionAction(connectionId: string): Promise<ActionResult<undefined>> {
  const result = await apiAction("DELETE", `/api/mcp-connections/${connectionId}`);
  if (result.ok) revalidatePath(ROUTES.SETTINGS_INTEGRATIONS);
  return result;
}
