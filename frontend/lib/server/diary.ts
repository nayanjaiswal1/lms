import "server-only";

import { apiGet } from "@/lib/server/api";

export type HighlightKind = "habit" | "task_done" | "task_new" | "buy_new" | "learned" | "goal";

export interface DiaryHighlight {
  start: number;
  end: number;
  text: string;
  kind: HighlightKind;
  ref_id: string | null;
  // Set only for kind "habit", when the habit has a structured entry form
  // (gym/sleep/reading/custom) and the AI extracted values for one or more
  // of its fields from this span — see docs/diary.md.
  metadata?: Record<string, unknown>;
  // Set only for kind "learned": category is the Learning Log section
  // title, title the module title ref_id resolves to once applied.
  category?: string;
  title?: string;
  // Set only for kind "goal": one of "daily"/"weekly"/"monthly" — the
  // cadence of the habit ref_id resolves to once applied.
  cadence?: string;
}

export interface AnalyzePreviewResponse {
  highlights: DiaryHighlight[];
}

export interface ReviewResponse {
  content: string;
  highlights: DiaryHighlight[];
}

export interface DiaryGoal {
  id: string;
  name: string;
  cadence: string;
  done: boolean;
}

export interface DiaryEntry {
  id: string;
  entry_date: string;
  content: string;
  highlights: DiaryHighlight[];
  analyzed_at: string | null;
  created_at: string;
  updated_at: string;
  goals: DiaryGoal[];
}

export type DiaryTaskKind = "todo" | "buy";

export interface DiaryTask {
  id: string;
  title: string;
  kind: DiaryTaskKind;
  tags: string[];
  done: boolean;
  source_entry_id?: string;
  created_at: string;
  updated_at: string;
}

export interface DiaryTaskListResponse {
  tasks: DiaryTask[];
}

export interface DiaryEntryPreview {
  id: string;
  entry_date: string;
  preview: string;
}

export interface DiaryHistoryPage {
  entries: DiaryEntryPreview[];
  next_cursor: string | null;
}

export type FixEnglishSegmentKind = "same" | "del" | "add";

export interface FixEnglishSegment {
  kind: FixEnglishSegmentKind;
  text: string;
}

export async function getTodayEntry(): Promise<DiaryEntry> {
  return apiGet<DiaryEntry>("/api/diary/today");
}

export async function getEntryByDate(date: string): Promise<DiaryEntry> {
  return apiGet<DiaryEntry>(`/api/diary/${encodeURIComponent(date)}`);
}

export interface DiaryHistoryFilter {
  from?: string;
  to?: string;
  cursor?: string;
  limit?: number;
}

export async function getDiaryHistory(filter?: DiaryHistoryFilter): Promise<DiaryHistoryPage> {
  const params = new URLSearchParams();
  if (filter?.from) params.set("from", filter.from);
  if (filter?.to) params.set("to", filter.to);
  if (filter?.cursor) params.set("cursor", filter.cursor);
  if (filter?.limit) params.set("limit", String(filter.limit));
  const query = params.toString();
  return apiGet<DiaryHistoryPage>(`/api/diary${query ? `?${query}` : ""}`);
}

export interface DiaryTaskFilter {
  tag?: string;
  done?: boolean;
}

export async function getDiaryTasks(filter?: DiaryTaskFilter): Promise<DiaryTaskListResponse> {
  const params = new URLSearchParams();
  if (filter?.tag) params.set("tag", filter.tag);
  if (filter?.done !== undefined) params.set("done", String(filter.done));
  const query = params.toString();
  return apiGet<DiaryTaskListResponse>(`/api/diary/tasks${query ? `?${query}` : ""}`);
}
