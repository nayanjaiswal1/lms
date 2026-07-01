"use server"

import { apiAction } from "@/lib/server/api"
import type { ActionResult } from "@/lib/server/api"
import type { Highlight, ExplainResponse, HighlightSourceType } from "@/lib/server/highlights"

interface CreatePayload {
  source_type: HighlightSourceType
  source_id: string
  selected_text: string
  position_start?: number
  position_end?: number
  context_snippet?: string
  source_url?: string
  save_for_revision: boolean
}

interface ExplainPayload {
  source_type: HighlightSourceType
  source_id: string
  selected_text: string
  position_start?: number
  position_end?: number
  context_snippet?: string
  source_url?: string
}

export async function createHighlightAction(
  payload: CreatePayload,
): Promise<ActionResult<Highlight>> {
  return apiAction<Highlight>("POST", "/api/highlights", payload)
}

export async function explainHighlightAction(
  payload: ExplainPayload,
): Promise<ActionResult<ExplainResponse>> {
  return apiAction<ExplainResponse>("POST", "/api/highlights/explain", payload)
}

export async function toggleRevisionAction(
  highlightId: string,
  save_for_revision: boolean,
): Promise<ActionResult<Highlight>> {
  return apiAction<Highlight>("PATCH", `/api/highlights/${highlightId}/revision`, {
    save_for_revision,
  })
}
