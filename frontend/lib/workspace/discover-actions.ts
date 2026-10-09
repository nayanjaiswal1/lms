"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

interface InterestInput {
  skills?: string[];
  portfolio_url?: string;
  message?: string;
}

export async function registerWorkspaceInterestAction(workspaceId: string, input?: InterestInput): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/workspaces/${workspaceId}/interest`, input);
  if (result.ok) revalidatePath(ROUTES.WORKSPACES_DISCOVER);
  return result;
}

export async function withdrawWorkspaceInterestAction(workspaceId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/workspaces/${workspaceId}/interest`);
  if (result.ok) revalidatePath(ROUTES.WORKSPACES_DISCOVER);
  return result;
}
