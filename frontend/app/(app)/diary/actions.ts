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
} from "@/lib/server/diary";
import type { Habit, HabitCadence } from "@/lib/server/habits";

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

export async function updateDiaryTaskDetailsAction(
  id: string,
  title: string,
  description: string,
): Promise<ActionResult<DiaryTask>> {
  const result = await apiAction<DiaryTask>("PATCH", `/api/diary/tasks/${encodeURIComponent(id)}`, {
    title,
    description,
  });
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

// ─── Diary "Goals" strip (a read display over the habit tracker — see
// GoalStatus in internal/diary/models.go) ───────────────────────────────────
//
// These call the habit domain's own endpoints directly (no diary-owned
// goal table) so creating/completing/removing a goal from the diary page
// stays the exact same habit the Habits page shows.

// Creates a habit, then re-fetches the entry so the new goal comes back
// with its server-computed `period` (daily/ISO-week-Monday/month-1st
// alignment — see alignPeriod in internal/diary/service.go) instead of
// reimplementing that alignment on the frontend.
export async function createDiaryGoalAction(
  date: string,
  name: string,
  cadence: HabitCadence,
): Promise<ActionResult<DiaryEntry>> {
  const created = await apiAction<Habit>("POST", "/api/habits", { name, cadence });
  if (!created.ok) return { ok: false, error: created.error, fieldErrors: created.fieldErrors };
  const result = await apiAction<DiaryEntry>("GET", `/api/diary/${encodeURIComponent(date)}`);
  if (result.ok) revalidatePath(ROUTES.DIARY);
  return result;
}

export async function toggleDiaryGoalAction(
  habitId: string,
  period: string,
  done: boolean,
): Promise<ActionResult<null>> {
  const result = done
    ? await apiAction<null>("PUT", `/api/habits/${encodeURIComponent(habitId)}/completions/${encodeURIComponent(period)}`)
    : await apiAction<null>("DELETE", `/api/habits/${encodeURIComponent(habitId)}/completions/${encodeURIComponent(period)}`);
  if (result.ok) revalidatePath(ROUTES.DIARY);
  return result;
}

export async function deleteDiaryGoalAction(habitId: string): Promise<ActionResult<null>> {
  const result = await apiAction<null>("DELETE", `/api/habits/${encodeURIComponent(habitId)}`);
  if (result.ok) revalidatePath(ROUTES.DIARY);
  return result;
}
