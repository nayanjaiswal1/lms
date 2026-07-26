"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { McpActionLogEntry } from "@/components/settings/mcp-action-log";

export async function revertMcpActionAction(entryId: string): Promise<ActionResult<McpActionLogEntry>> {
  const result = await apiAction<McpActionLogEntry>("POST", `/api/mcp-action-log/${entryId}/revert`);
  if (result.ok) revalidatePath(ROUTES.SETTINGS_INTEGRATIONS_ACTIVITY);
  return result;
}
