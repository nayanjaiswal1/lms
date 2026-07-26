import "server-only";

import { apiGet } from "@/lib/server/api";

export interface MistakeEntry {
  id: string;
  category: string;
  sub_topic: string;
  original_text: string;
  corrected_text: string;
  context_tag: string | null;
  source_module_id: string | null;
  resolved_at: string | null;
  created_at: string;
  status: "new" | "recurring" | "improving" | "resolved";
}

export interface CategorySummary {
  category: string;
  total: number;
  first_occurred_at: string;
  last_occurred_at: string;
  trend: "worsening" | "stable" | "improving";
}

export interface MistakeFilter {
  category?: string;
  context_tag?: string;
}

export async function getMistakes(filter: MistakeFilter = {}): Promise<MistakeEntry[]> {
  const params = new URLSearchParams();
  if (filter.category) params.set("category", filter.category);
  if (filter.context_tag) params.set("context_tag", filter.context_tag);
  const qs = params.toString();
  const data = await apiGet<{ entries: MistakeEntry[] }>(`/api/mistakes${qs ? `?${qs}` : ""}`);
  return data.entries ?? [];
}

export async function getMistakeSummary(): Promise<CategorySummary[]> {
  const data = await apiGet<{ categories: CategorySummary[] }>("/api/mistakes/summary");
  return data.categories ?? [];
}
