"use server";

import { revalidatePath } from "next/cache";

import { apiAction, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { DiaryEntry, FixEnglishSegment } from "@/lib/server/diary";

export async function saveDiaryEntryAction(date: string, content: string): Promise<ActionResult<DiaryEntry>> {
  const result = await apiAction<DiaryEntry>("PATCH", `/api/diary/${encodeURIComponent(date)}`, { content });
  if (result.ok) {
    revalidatePath(ROUTES.DIARY);
    revalidatePath(ROUTES.DIARY_HISTORY);
  }
  return result;
}

export async function fixEnglishAction(
  date: string,
  content: string,
): Promise<ActionResult<{ segments: FixEnglishSegment[] }>> {
  return apiAction<{ segments: FixEnglishSegment[] }>(
    "POST",
    `/api/diary/${encodeURIComponent(date)}/fix-english`,
    { content },
  );
}
