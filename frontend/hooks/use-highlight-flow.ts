"use client"

import { useState, useTransition } from "react"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import {
  createHighlightAction,
  explainHighlightAction,
  toggleRevisionAction,
} from "@/app/(app)/highlights/actions"
import { isMeaningfulSelection } from "@/lib/highlights/stop-words"
import type { Highlight, ExplainResponse, HighlightSourceType } from "@/lib/server/highlights"

// Viewport-relative anchor for popup positioning + context captured at selection time.
interface Anchor {
  text: string
  top: number
  left: number
  width: number
  contextSnippet: string
  sourceUrl: string
  // Which lesson segment the selection was made in, and which occurrence
  // (0-based) of `text` within that segment it was — lets a highlight on a
  // sentence that repeats elsewhere in the lesson be told apart from its
  // duplicates. Null when the selection couldn't be anchored to a segment
  // (e.g. selection spans outside any [data-segment-index] element).
  positionStart: number | null
  positionEnd: number | null
}

type IdleState = { phase: "idle" }
type SelectedState = {
  phase: "selected"
  anchor: Anchor
  // Set when this exact text was already highlighted on this page — lets the
  // popup show a distinct "already saved" state instead of a plain Save button.
  existing: Highlight | null
}
type ExplainedState = {
  phase: "explained"
  anchor: Anchor
  highlightId: string
  response: ExplainResponse
  savedForRevision: boolean
  note: string
}

type FlowState = IdleState | SelectedState | ExplainedState

export interface HighlightFlow {
  selection: Anchor | null
  existing: Highlight | null
  response: ExplainResponse | null
  savedForRevision: boolean
  note: string
  isLoading: boolean
  onTextSelected: (
    text: string,
    rect: Pick<DOMRect, "top" | "left" | "width">,
    contextSnippet: string,
    sourceUrl: string,
    positionStart: number | null,
    positionEnd: number | null,
  ) => void
  onSaveRevision: (note: string) => void
  onExplain: () => void
  onToggleSaved: (save: boolean, note?: string) => void
  onClose: () => void
}

function findExisting(
  highlights: Highlight[],
  text: string,
  positionStart: number | null,
  positionEnd: number | null,
): Highlight | null {
  const normalized = text.trim().toLowerCase()
  const matchesPosition = (h: Highlight) =>
    positionStart !== null &&
    positionEnd !== null &&
    h.position_start === positionStart &&
    h.position_end === positionEnd
  const matchesText = (h: Highlight) => h.selected_text.trim().toLowerCase() === normalized

  // Prefer a highlight already saved for revision over one only created by a
  // past "Explain" click, since that's the state most worth surfacing.
  // Position match takes priority so a repeated sentence elsewhere in the
  // lesson isn't reported as "already saved". Highlights created before
  // position tracking existed (position_start === null) have no anchor to
  // match on, so they fall back to text-only.
  return (
    highlights.find((h) => h.saved_for_revision && matchesPosition(h)) ??
    highlights.find((h) => matchesPosition(h)) ??
    highlights.find((h) => h.saved_for_revision && h.position_start === null && matchesText(h)) ??
    highlights.find((h) => h.position_start === null && matchesText(h)) ??
    null
  )
}

export function useHighlightFlow(
  sourceType: HighlightSourceType,
  sourceId: string,
  initialHighlights: Highlight[] = [],
): HighlightFlow {
  const [flow, setFlow] = useState<FlowState>({ phase: "idle" })
  const [highlights, setHighlights] = useState<Highlight[]>(initialHighlights)
  const [isPending, startTransition] = useTransition()
  const router = useRouter()

  const selection = flow.phase !== "idle" ? flow.anchor : null
  const existing = flow.phase === "selected" ? flow.existing : null
  const response = flow.phase === "explained" ? flow.response : null
  const savedForRevision = flow.phase === "explained" ? flow.savedForRevision : false
  const note = flow.phase === "explained" ? flow.note : (existing?.note ?? "")

  function upsertHighlight(updated: Highlight) {
    setHighlights((prev) => {
      const idx = prev.findIndex((h) => h.id === updated.id)
      if (idx === -1) return [updated, ...prev]
      const next = [...prev]
      next[idx] = updated
      return next
    })
  }

  function onTextSelected(
    text: string,
    rect: Pick<DOMRect, "top" | "left" | "width">,
    contextSnippet: string,
    sourceUrl: string,
    positionStart: number | null,
    positionEnd: number | null,
  ) {
    if (text.trim().length < 3 || !isMeaningfulSelection(text)) return
    setFlow({
      phase: "selected",
      anchor: {
        text: text.trim(),
        top: rect.top,
        left: rect.left,
        width: rect.width,
        contextSnippet,
        sourceUrl,
        positionStart,
        positionEnd,
      },
      existing: findExisting(highlights, text, positionStart, positionEnd),
    })
  }

  function onClose() {
    setFlow({ phase: "idle" })
  }

  function onSaveRevision(noteText: string) {
    if (flow.phase !== "selected") return
    const { anchor, existing: current } = flow
    const trimmedNote = noteText.trim()

    startTransition(async () => {
      if (current) {
        // Already highlighted on this page — update it in place instead of
        // creating a duplicate row for the same selected text.
        const result = await toggleRevisionAction(current.id, true, trimmedNote)
        if (result.ok && result.data) {
          upsertHighlight(result.data)
          toast.success("Highlight updated")
          setFlow({ phase: "idle" })
          router.refresh()
        } else {
          toast.error(result.error ?? "Failed to update highlight")
        }
        return
      }

      const result = await createHighlightAction({
        source_type: sourceType,
        source_id: sourceId,
        selected_text: anchor.text,
        position_start: anchor.positionStart ?? undefined,
        position_end: anchor.positionEnd ?? undefined,
        context_snippet: anchor.contextSnippet || undefined,
        source_url: anchor.sourceUrl || undefined,
        save_for_revision: true,
        note: trimmedNote || undefined,
      })
      if (result.ok && result.data) {
        upsertHighlight(result.data)
        toast.success("Saved for revision")
        setFlow({ phase: "idle" })
        router.refresh()
      } else {
        toast.error(result.error ?? "Failed to save highlight")
      }
    })
  }

  function onExplain() {
    if (flow.phase !== "selected") return
    const { anchor, existing: current } = flow
    startTransition(async () => {
      const result = await explainHighlightAction({
        source_type: sourceType,
        source_id: sourceId,
        selected_text: anchor.text,
        position_start: anchor.positionStart ?? undefined,
        position_end: anchor.positionEnd ?? undefined,
        context_snippet: anchor.contextSnippet || undefined,
        source_url: anchor.sourceUrl || undefined,
      })
      if (result.ok && result.data) {
        setFlow({
          phase: "explained",
          anchor,
          highlightId: result.data.highlight_id,
          response: result.data,
          savedForRevision: current?.saved_for_revision ?? false,
          note: current?.note ?? "",
        })
      } else {
        toast.error(result.error ?? "Failed to get explanation")
      }
    })
  }

  function onToggleSaved(save: boolean, noteText?: string) {
    if (flow.phase !== "explained") return
    const current = flow
    startTransition(async () => {
      const result = await toggleRevisionAction(current.highlightId, save, noteText?.trim())
      if (result.ok && result.data) {
        upsertHighlight(result.data)
        setFlow({ ...current, savedForRevision: save, note: result.data.note ?? current.note })
        toast.success(save ? "Saved for revision" : "Removed from revision")
        router.refresh()
      } else {
        toast.error(result.error ?? "Failed to update")
      }
    })
  }

  return {
    selection,
    existing,
    response,
    savedForRevision,
    note,
    isLoading: isPending,
    onTextSelected,
    onSaveRevision,
    onExplain,
    onToggleSaved,
    onClose,
  }
}
