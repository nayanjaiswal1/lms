"use server";

import { updateOrgQuota } from "@/lib/server/admin-jobs";
import { revalidatePath } from "next/cache";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export async function updateQuotaAction(
  orgID: string,
  _prevState: ActionResult,
  formData: FormData,
): Promise<ActionResult> {
  const max_concurrent = parseInt(formData.get("max_concurrent") as string, 10);
  const max_queued = parseInt(formData.get("max_queued") as string, 10);
  const priority_floor = parseInt(formData.get("priority_floor") as string, 10);

  if (
    isNaN(max_concurrent) ||
    max_concurrent < 1 ||
    max_concurrent > 50
  ) {
    return { error: "max_concurrent must be between 1 and 50." };
  }
  if (
    isNaN(max_queued) ||
    max_queued < 10 ||
    max_queued > 1000
  ) {
    return { error: "max_queued must be between 10 and 1000." };
  }
  if (![1, 2, 3, 4, 5].includes(priority_floor)) {
    return { error: "Invalid priority floor value." };
  }

  try {
    await updateOrgQuota(orgID, { max_concurrent, max_queued, priority_floor });
    revalidatePath(ROUTES.ADMIN_JOBS);
    revalidatePath(ROUTES.adminOrgQuotas(orgID));
    return { ok: true };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Failed to update quota." };
  }
}
