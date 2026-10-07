"use server";

import { apiActionPublic, type ActionResult } from "@/lib/server/api";
import type { PublicSession } from "@/lib/server/public";

export async function startPublicAttemptAction(
  code: string,
  body: { name: string; email: string; phone?: string },
): Promise<ActionResult<PublicSession>> {
  return apiActionPublic<PublicSession>("POST", `/api/p/${code}/start`, body);
}

export async function submitPublicAttemptAction(
  code: string,
  token: string,
  answers: Record<string, string[]>,
): Promise<ActionResult<{ percentage: number; passed: boolean; score: number; max_score: number }>> {
  // Convert {aqId: [optionId, ...]} to {aqId: {selected: [optionId, ...]}}
  const payload: Record<string, { selected: string[] }> = {};
  for (const [aqId, selected] of Object.entries(answers)) {
    payload[aqId] = { selected };
  }
  return apiActionPublic<{ percentage: number; passed: boolean; score: number; max_score: number }>(
    "POST",
    `/api/p/${code}/submit`,
    { answers: payload },
    { "X-Attempt-Token": token },
  );
}
