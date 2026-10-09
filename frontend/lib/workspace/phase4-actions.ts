"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { Project, TimeLog, TimeLogInput } from "@/lib/workspace/types";

export async function logTimeAction(workspaceId: string, itemId: string, input: TimeLogInput): Promise<ActionResult<TimeLog>> {
  // Revalidated by the caller's own router.refresh() (same pattern
  // item-overview-tabs.tsx already uses for description edits) — this
  // action doesn't know the item's display key, only its id, so it can't
  // build ROUTES.workspaceItem() itself.
  return apiAction<TimeLog>("POST", `/api/workspaces/${workspaceId}/items/${itemId}/time-logs`, input);
}

export async function updateTimeLogAction(workspaceId: string, logId: string, input: TimeLogInput): Promise<ActionResult<TimeLog>> {
  return apiAction<TimeLog>("PATCH", `/api/workspaces/${workspaceId}/time-logs/${logId}`, input);
}

export async function deleteTimeLogAction(workspaceId: string, logId: string): Promise<ActionResult> {
  return apiAction("DELETE", `/api/workspaces/${workspaceId}/time-logs/${logId}`);
}

export async function provisionGitlabAction(workspaceId: string, installationId?: string): Promise<ActionResult<Project>> {
  const result = await apiAction<Project>("POST", `/api/workspaces/${workspaceId}/gitlab/provision`, installationId ? { installation_id: installationId } : undefined);
  if (result.ok) revalidatePath(ROUTES.workspaceSettings(workspaceId));
  return result;
}
