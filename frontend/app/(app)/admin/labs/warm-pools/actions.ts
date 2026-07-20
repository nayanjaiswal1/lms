"use server";

import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import { revalidatePath } from "next/cache";
import ROUTES from "@/lib/routes";

interface WarmPoolConfigPayload {
  mode: string;
  fixed_size: number;
  max_size: number;
}

export async function updateWarmPoolConfigAction(
  labId: string,
  payload: WarmPoolConfigPayload,
): Promise<ActionResult> {
  const result = await apiAction("PUT", `/api/admin/labs/${labId}/warm-pool`, payload);
  if (result.ok) revalidatePath(ROUTES.ADMIN_LABS_WARM_POOLS);
  return result;
}
