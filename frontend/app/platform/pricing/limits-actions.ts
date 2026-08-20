"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import type { PlanLimit } from "@/lib/server/entitlements";
import ROUTES from "@/lib/routes";

export interface UpdatePlanLimitInput {
  kind: PlanLimit["kind"];
  bool_value?: boolean;
  numeric_value?: number;
  period?: string;
}

export async function updatePlanLimitAction(
  tierId: string,
  featureKey: string,
  input: UpdatePlanLimitInput,
): Promise<ActionResult<PlanLimit>> {
  const result = await apiAction<PlanLimit>("PUT", `/api/admin/plan-limits/${tierId}/${featureKey}`, input);
  if (result.ok) revalidatePath(ROUTES.PLATFORM_PRICING);
  return result;
}
