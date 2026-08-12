import "server-only";

import { apiGet } from "@/lib/server/api";

export interface JournalEntry {
  id: string;
  user_id: string;
  entry_date: string;
  category: string;
  subcategory: string;
  title: string;
  content: string;
  created_at: string;
  updated_at: string;
}

export interface CreateJournalEntryResult {
  entry: JournalEntry;
  similar_entries: JournalEntry[];
}

export interface CreateJournalEntryInput {
  entry_date?: string;
  category: string;
  subcategory: string;
  title: string;
  content: string;
}

export interface UpdateJournalEntryInput {
  entry_date?: string;
  category?: string;
  subcategory?: string;
  title?: string;
  content?: string;
}

export interface JournalEntriesFilter {
  category?: string;
  subcategory?: string;
  search?: string;
}

/** One entry in the caller's category -> subcategories tree. */
export interface JournalCategoryNode {
  category: string;
  subcategories: string[];
}

/** AI's suggested category/subcategory/title for a block of pasted text — a
 * suggestion only; the caller supplies the pasted text itself as content
 * when actually creating the entry. */
export interface StructureJournalEntryResult {
  category: string;
  subcategory: string;
  title: string;
}

export async function getJournalEntries(filter?: JournalEntriesFilter): Promise<JournalEntry[]> {
  const params = new URLSearchParams();
  if (filter?.category) params.set("category", filter.category);
  if (filter?.subcategory) params.set("subcategory", filter.subcategory);
  if (filter?.search) params.set("q", filter.search);
  const query = params.toString();
  return apiGet<JournalEntry[]>(`/api/journal${query ? `?${query}` : ""}`);
}

export async function getJournalCategories(): Promise<JournalCategoryNode[]> {
  return apiGet<JournalCategoryNode[]>("/api/journal/categories");
}

export async function getJournalEntry(id: string): Promise<JournalEntry> {
  return apiGet<JournalEntry>(`/api/journal/${encodeURIComponent(id)}`);
}
