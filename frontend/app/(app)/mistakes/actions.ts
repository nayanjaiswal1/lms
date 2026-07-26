"use server";

import { apiAction } from "@/lib/server/api";

export interface ResolveMistakeResult {
  ok: boolean;
  error?: string;
}

export async function resolveMistakeAction(entryId: string): Promise<ResolveMistakeResult> {
  const result = await apiAction("POST", `/api/mistakes/${entryId}/resolve`);
  return { ok: !!result.ok, error: result.error };
}
