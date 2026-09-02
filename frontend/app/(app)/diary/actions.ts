"use server";

import { revalidatePath } from "next/cache";

import { apiAction, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type {
  AnalyzePreviewResponse,
  DiaryEntry,
  DiaryHighlight,
  DiaryTask,
  DiaryTaskKind,
  FixEnglishSegment,
  ReviewResponse,
} from "@/lib/server/diary";

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

// The single "AI" button: FixEnglish then Analyze over the corrected text in
// one round trip — see internal/diary.Service.ReviewDump. Nothing is saved
// or applied here; the caller still saves the corrected content and confirms
// the reviewed highlights via saveDiaryEntryAction/applyAnalysisAction.
export async function reviewDumpAction(date: string, content: string): Promise<ActionResult<ReviewResponse>> {
  return apiAction<ReviewResponse>("POST", `/api/diary/${encodeURIComponent(date)}/review`, { content });
}

// ─── Diary-owned tasks ──────────────────────────────────────────────────────

export async function listDiaryTasksAction(
  filter?: { tag?: string; done?: boolean },
): Promise<ActionResult<{ tasks: DiaryTask[] }>> {
  const params = new URLSearchParams();
  if (filter?.tag) params.set("tag", filter.tag);
  if (filter?.done !== undefined) params.set("done", String(filter.done));
  const query = params.toString();
  const result = await apiAction<{ tasks: DiaryTask[] }>("GET", `/api/diary/tasks${query ? `?${query}` : ""}`);
  return result;
}

export async function createDiaryTaskAction(
  title: string,
  kind: DiaryTaskKind,
  tags: string[],
): Promise<ActionResult<DiaryTask>> {
  const result = await apiAction<DiaryTask>("POST", "/api/diary/tasks", { title, kind, tags });
  if (result.ok) revalidatePath(ROUTES.DIARY);
  return result;
}

export async function toggleDiaryTaskAction(id: string, done: boolean): Promise<ActionResult<DiaryTask>> {
  const result = await apiAction<DiaryTask>("PATCH", `/api/diary/tasks/${encodeURIComponent(id)}`, { done });
  if (result.ok) revalidatePath(ROUTES.DIARY);
  return result;
}

export async function updateDiaryTaskTagsAction(id: string, tags: string[]): Promise<ActionResult<DiaryTask>> {
  const result = await apiAction<DiaryTask>("PATCH", `/api/diary/tasks/${encodeURIComponent(id)}`, { tags });
  if (result.ok) revalidatePath(ROUTES.DIARY);
  return result;
}

export async function deleteDiaryTaskAction(id: string): Promise<ActionResult<void>> {
  const result = await apiAction<void>("DELETE", `/api/diary/tasks/${encodeURIComponent(id)}`);
  if (result.ok) revalidatePath(ROUTES.DIARY);
  return result;
}
