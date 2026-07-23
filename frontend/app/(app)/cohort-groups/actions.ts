"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export interface CohortGroupInput {
  name: string;
  parent_id?: string | null;
  level_label?: string | null;
}

export async function createCohortGroupAction(input: CohortGroupInput): Promise<ActionResult> {
  const result = await apiAction("POST", "/api/cohort-groups", input);
  if (result.ok) revalidatePath(ROUTES.COHORT_GROUPS);
  return result;
}

export async function updateCohortGroupAction(groupId: string, input: CohortGroupInput): Promise<ActionResult> {
  const result = await apiAction("PATCH", `/api/cohort-groups/${groupId}`, input);
  if (result.ok) revalidatePath(ROUTES.COHORT_GROUPS);
  return result;
}

export async function archiveCohortGroupAction(groupId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/cohort-groups/${groupId}`);
  if (result.ok) revalidatePath(ROUTES.COHORT_GROUPS);
  return result;
}

export async function moveBatchToGroupAction(batchId: string, cohortGroupId: string | null): Promise<ActionResult> {
  const result = await apiAction("PUT", `/api/batches/${batchId}/cohort-group`, { cohort_group_id: cohortGroupId });
  if (result.ok) {
    revalidatePath(ROUTES.COHORT_GROUPS);
    revalidatePath(ROUTES.BATCHES);
  }
  return result;
}
