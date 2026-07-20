"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { CodingItem, PrepPlan } from "@/lib/server/interview-prep";

export async function createPrepPlanAction(input: {
  job_title: string;
  jd_text?: string;
}): Promise<ActionResult<PrepPlan>> {
  const result = await apiAction<PrepPlan>("POST", "/api/interview-prep", input);
  if (result.ok) revalidatePath(ROUTES.INTERVIEW_PREP);
  return result;
}

export async function submitCodingItemAction(
  planId: string,
  roundId: string,
  itemId: string,
  code: string,
  language: string,
): Promise<ActionResult<CodingItem>> {
  const result = await apiAction<CodingItem>(
    "POST",
    `/api/interview-prep/${planId}/rounds/${roundId}/items/${itemId}/submit`,
    { code, language },
  );
  if (result.ok) revalidatePath(ROUTES.interviewPrepCoding(planId));
  return result;
}
