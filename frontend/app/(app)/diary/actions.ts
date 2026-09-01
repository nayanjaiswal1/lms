"use server";

import { revalidatePath } from "next/cache";

import { apiAction, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { AnalyzePreviewResponse, DiaryEntry, DiaryHighlight, FixEnglishSegment } from "@/lib/server/diary";

export async function saveDiaryEntryAction(date: string, content: string): Promise<ActionResult<DiaryEntry>> {
  const result = await apiAction<DiaryEntry>("PATCH", `/api/diary/${encodeURIComponent(date)}`, { content });
  if (result.ok) {
    revalidatePath(ROUTES.DIARY);
    revalidatePath(ROUTES.diaryEntry(date));
  }
  return result;
}

// Synchronous, unpersisted habit/task detection over content (the writer's
// current text, which may not be saved yet) — mirrors fixEnglishAction.
// Nothing is written to habits/tasks until the reviewed result is confirmed
// via applyAnalysisAction below.
export async function analyzePreviewAction(date: string, content: string): Promise<ActionResult<AnalyzePreviewResponse>> {
  return apiAction<AnalyzePreviewResponse>("POST", `/api/diary/${encodeURIComponent(date)}/analyze/preview`, {
    content,
  });
}

// Commits the writer-reviewed (possibly edited/filtered) highlight list from
// analyzePreviewAction into the real habit/whatnow records.
export async function applyAnalysisAction(
  date: string,
  highlights: DiaryHighlight[],
): Promise<ActionResult<DiaryEntry>> {
  const result = await apiAction<DiaryEntry>("POST", `/api/diary/${encodeURIComponent(date)}/analyze/apply`, {
    highlights,
  });
  if (result.ok) {
    revalidatePath(ROUTES.DIARY);
    revalidatePath(ROUTES.diaryEntry(date));
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
