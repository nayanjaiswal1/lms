"use client"

import { useState, useTransition } from "react"
import { toast } from "sonner"
import {
  createHighlightAction,
  explainHighlightAction,
  toggleRevisionAction,
} from "@/app/(app)/highlights/actions"
import type { ExplainResponse, HighlightSourceType } from "@/lib/server/highlights"

// Viewport-relative anchor for popup positioning + context captured at selection time.
interface Anchor {
  text: string
  top: number
  left: number
  width: number
  contextSnippet: string
  sourceUrl: string
}

type IdleState = { phase: "idle" }
type SelectedState = { phase: "selected"; anchor: Anchor }
type ExplainedState = {
  phase: "explained"
  anchor: Anchor
  highlightId: string
  response: ExplainResponse
  savedForRevision: boolean
}

type FlowState = IdleState | SelectedState | ExplainedState

export interface HighlightFlow {
  selection: Anchor | null
  response: ExplainResponse | null
  savedForRevision: boolean
  isLoading: boolean
  onTextSelected: (
    text: string,
    rect: Pick<DOMRect, "top" | "left" | "width">,
    contextSnippet: string,
    sourceUrl: string,
  ) => void
  onSaveRevision: () => void
  onExplain: () => void
  onToggleSaved: (save: boolean) => void
  onClose: () => void
}

export function useHighlightFlow(
  sourceType: HighlightSourceType,
  sourceId: string,
): HighlightFlow {
  const [flow, setFlow] = useState<FlowState>({ phase: "idle" })
  const [isPending, startTransition] = useTransition()

  const selection = flow.phase !== "idle" ? flow.anchor : null
  const response = flow.phase === "explained" ? flow.response : null
  const savedForRevision = flow.phase === "explained" ? flow.savedForRevision : false

  function onTextSelected(
    text: string,
    rect: Pick<DOMRect, "top" | "left" | "width">,
    contextSnippet: string,
    sourceUrl: string,
  ) {
    if (text.trim().length < 3) return
    setFlow({
      phase: "selected",
      anchor: {
        text: text.trim(),
        top: rect.top,
        left: rect.left,
        width: rect.width,
        contextSnippet,
        sourceUrl,
      },
    })
  }

  function onClose() {
    setFlow({ phase: "idle" })
  }

  function onSaveRevision() {
    if (flow.phase !== "selected") return
    const { anchor } = flow
    startTransition(async () => {
      const result = await createHighlightAction({
        source_type: sourceType,
        source_id: sourceId,
        selected_text: anchor.text,
        context_snippet: anchor.contextSnippet || undefined,
        source_url: anchor.sourceUrl || undefined,
        save_for_revision: true,
      })
      if (result.ok) {
        toast.success("Saved for revision")
        setFlow({ phase: "idle" })
      } else {
        toast.error(result.error ?? "Failed to save highlight")
      }
    })
  }

  function onExplain() {
    if (flow.phase !== "selected") return
    const { anchor } = flow
    startTransition(async () => {
      const result = await explainHighlightAction({
        source_type: sourceType,
        source_id: sourceId,
        selected_text: anchor.text,
        context_snippet: anchor.contextSnippet || undefined,
        source_url: anchor.sourceUrl || undefined,
      })
      if (result.ok && result.data) {
        setFlow({
          phase: "explained",
          anchor,
          highlightId: result.data.highlight_id,
          response: result.data,
          savedForRevision: false,
        })
      } else {
        toast.error(result.error ?? "Failed to get explanation")
      }
    })
  }

  function onToggleSaved(save: boolean) {
    if (flow.phase !== "explained") return
    const current = flow
    startTransition(async () => {
      const result = await toggleRevisionAction(current.highlightId, save)
      if (result.ok) {
        setFlow({ ...current, savedForRevision: save })
        toast.success(save ? "Saved for revision" : "Removed from revision")
      } else {
        toast.error(result.error ?? "Failed to update")
      }
    })
  }

  return {
    selection,
    response,
    savedForRevision,
    isLoading: isPending,
    onTextSelected,
    onSaveRevision,
    onExplain,
    onToggleSaved,
    onClose,
  }
}
