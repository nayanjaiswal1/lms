import { apiGet } from "@/lib/server/api"

export type HighlightSourceType = "wiki_page" | "lesson" | "problem"

export interface Highlight {
  id: string
  user_id: string
  source_type: HighlightSourceType
  source_id: string
  selected_text: string
  text_hash: string
  position_start: number | null
  position_end: number | null
  context_snippet: string | null
  source_url: string | null
  source_orphaned: boolean
  saved_for_revision: boolean
  explanation?: Explanation
  created_at: string
  updated_at: string
}

export interface Explanation {
  id: string
  text_hash: string
  selected_text: string
  source_type: string
  explanation: string
  model_used: string
  serve_count: number
  from_cache: boolean
  created_at: string
  updated_at: string
}

export interface ExplainResponse {
  highlight_id: string
  explanation: Explanation | null
}

export interface AnalyticsEntry {
  text_hash: string
  selected_text: string
  source_type: string
  serve_count: number
  model_used: string
  created_at: string
}

export async function getHighlightsForSource(
  sourceType: HighlightSourceType,
  sourceId: string,
): Promise<Highlight[]> {
  return apiGet<Highlight[]>(
    `/api/highlights?source_type=${encodeURIComponent(sourceType)}&source_id=${encodeURIComponent(sourceId)}`,
  )
}

export async function getMyHighlights(savedOnly = false): Promise<Highlight[]> {
  const qs = savedOnly ? "?saved_only=true" : ""
  return apiGet<Highlight[]>(`/api/highlights/me${qs}`)
}

export async function getHighlightAnalytics(limit = 50): Promise<AnalyticsEntry[]> {
  return apiGet<AnalyticsEntry[]>(`/api/admin/highlights/analytics?limit=${limit}`)
}
