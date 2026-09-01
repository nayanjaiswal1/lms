import "server-only";

import { apiGet } from "@/lib/server/api";

export type HighlightKind = "habit" | "task_done" | "task_new" | "buy_new";

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
}

export interface AnalyzePreviewResponse {
  highlights: DiaryHighlight[];
}

export interface DiaryEntry {
  id: string;
  entry_date: string;
  content: string;
  highlights: DiaryHighlight[];
  analyzed_at: string | null;
  created_at: string;
  updated_at: string;
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
