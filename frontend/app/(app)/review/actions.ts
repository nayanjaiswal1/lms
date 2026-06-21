"use server";

import { apiAction } from "@/lib/server/api";

export interface ReviewResult {
  ok: boolean;
  nextDue?: string;
  error?: string;
}

// submitReviewAction records a card review with a quality rating.
// quality: 0=Again, 1=Hard, 2=Good, 3=Easy
export async function submitReviewAction(
  cardId: string,
  quality: number,
): Promise<ReviewResult> {
  const result = await apiAction<{ next_due: string; interval_days: number; ease_factor: number }>(
    "POST",
    "/api/srs/review",
    { card_id: cardId, quality },
  );
  return { ok: !!result.ok, nextDue: result.data?.next_due, error: result.error };
}
