"use server";

import { revalidatePath } from "next/cache";
import { apiAction, ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export type { ActionResult };

export async function createBatchAction(input: { name: string; description?: string; mentor_id?: string }): Promise<ActionResult> {
  const result = await apiAction("POST", "/api/batches", input);
  if (result.ok) revalidatePath(ROUTES.BATCHES);
  return result;
}

export async function addBatchMembersAction(batchId: string, userIds: string[]): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/batches/${batchId}/members`, { user_ids: userIds });
  if (result.ok) {
    revalidatePath(ROUTES.BATCHES);
    revalidatePath(ROUTES.batch(batchId));
  }
  return result;
}

export async function removeBatchMemberAction(batchId: string, userId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/batches/${batchId}/members/${userId}`);
  if (result.ok) {
    revalidatePath(ROUTES.BATCHES);
    revalidatePath(ROUTES.batch(batchId));
  }
  return result;
}
