import "server-only";

import type { JSONContent } from "@tiptap/react";
import { apiGet } from "@/lib/server/api";
import type { GrowthScheme } from "@/lib/constants";

export type ProgressStatus = "todo" | "done" | "revisit";
export type Difficulty = "easy" | "medium" | "hard";
export type { GrowthScheme };

export interface Sheet {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  category: string | null;
  is_system: boolean;
  created_by: string | null;
  source_sheet_ids?: string[];
  created_at: string;
  updated_at: string;
  item_count: number;
  topics?: string[];
}

export interface UserSheetSummary extends Sheet {
  role: "owner" | "subscriber";
  solved_count: number;
}

export interface SheetPreview extends Sheet {
  is_subscribed: boolean;
}

export interface UpdateSheetInput {
  name?: string;
  description?: string;
}

export interface SheetItem {
  id: string;
  sheet_id: string;
  title: string;
  topic_tag: string;
  category: string | null;
  difficulty: Difficulty | null;
  external_url: string | null;
  order_index: number;
  status: ProgressStatus;
  solved_at: string | null;
  revision_at: string | null;
  review_count: number;
  notes: JSONContent;
  is_starred: boolean;
  created_at: string;
}

export interface SheetItemsResponse {
  sheet: Sheet;
  items: SheetItem[];
}

export interface UserSheetSettings {
  base_revision_days: number;
  growth_scheme: GrowthScheme;
}

export interface CreateSheetInput {
  name: string;
  description?: string;
  category?: string;
}

export interface CombineSheetsInput {
  name: string;
  sheet_ids: string[];
  exclude_topic_tags?: string[];
}

export interface AddItemInput {
  title: string;
  category?: string;
  difficulty?: Difficulty;
  external_url?: string;
}

export interface ImportedSheetItem {
  title: string;
  category?: string;
  difficulty?: Difficulty;
}

export interface UpdateItemInput {
  title?: string;
  category?: string;
  difficulty?: Difficulty;
  external_url?: string;
}

export async function getPublicSheets(): Promise<Sheet[]> {
  return apiGet<Sheet[]>("/api/sheets/public");
}

export async function getUserSheets(): Promise<UserSheetSummary[]> {
  return apiGet<UserSheetSummary[]>("/api/user/sheets");
}

export async function getSheetPreview(slug: string): Promise<SheetPreview> {
  return apiGet<SheetPreview>(`/api/sheets/${encodeURIComponent(slug)}`);
}

export async function getSheetItems(slug: string): Promise<SheetItemsResponse> {
  return apiGet<SheetItemsResponse>(`/api/sheets/${encodeURIComponent(slug)}/items`);
}

export async function getSheetSettings(sheetId: string): Promise<UserSheetSettings> {
  return apiGet<UserSheetSettings>(`/api/sheets/settings?sheet_id=${encodeURIComponent(sheetId)}`);
}
