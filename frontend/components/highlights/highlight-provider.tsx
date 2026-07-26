"use client"

import { useHighlightFlow } from "@/hooks/use-highlight-flow"
import { captureContextFromSelection } from "@/lib/highlights/context"
import { HighlightPopup } from "./highlight-popup"
import { ExplanationPanel } from "./explanation-panel"
import type { Highlight, HighlightSourceType } from "@/lib/server/highlights"

interface HighlightProviderProps {
  children: React.ReactNode
  sourceType: HighlightSourceType
  sourceId: string
  // Pre-fetched server-side so re-selecting already-highlighted text shows
  // its saved state immediately instead of only after a round-trip.
  initialHighlights?: Highlight[]
}

// Finds which lesson segment a selection landed in (nearest ancestor with
// data-segment-index, set by LessonHtml) and which occurrence — 0-based, in
// document order — of the selected text within that segment's rendered text
// the selection is. Together these disambiguate a sentence that repeats
// elsewhere in the lesson from the specific instance the user picked; without
// them a saved highlight can only be matched back by text, which lights up
// every identical sentence on reload instead of just the one selected.
function findSegmentAnchor(range: Range, text: string): { segmentIndex: number; occurrence: number } | null {
  const startNode = range.startContainer
  const startEl = startNode.nodeType === Node.ELEMENT_NODE ? (startNode as Element) : startNode.parentElement
  const segmentEl = startEl?.closest("[data-segment-index]")
  if (!segmentEl) return null

  const segmentIndex = Number(segmentEl.getAttribute("data-segment-index"))
  if (Number.isNaN(segmentIndex)) return null

  const preRange = document.createRange()
  preRange.selectNodeContents(segmentEl)
  preRange.setEnd(range.startContainer, range.startOffset)
  const before = preRange.toString().toLowerCase()
  const needle = text.toLowerCase()

  let occurrence = 0
  let from = 0
  while (true) {
    const idx = before.indexOf(needle, from)
    if (idx === -1) break
    occurrence++
    from = idx + needle.length
  }

  return { segmentIndex, occurrence }
}

// Wraps any reading surface and enables the highlight flow.
// Do NOT mount on assessment attempt pages — AI assist during a live exam is cheating.
//
// Usage:
//   <HighlightProvider sourceType="lesson" sourceId={lesson.id}>
//     <LessonContent html={lesson.body} />
//   </HighlightProvider>
export function HighlightProvider({
  children,
  sourceType,
  sourceId,
  initialHighlights = [],
}: HighlightProviderProps) {
  const {
    selection,
    existing,
    response,
    savedForRevision,
    note,
    isLoading,
    onTextSelected,
    onSaveRevision,
    onExplain,
    onToggleSaved,
    onClose,
  } = useHighlightFlow(sourceType, sourceId, initialHighlights)

  function handleMouseUp() {
    const sel = window.getSelection()
    if (!sel || sel.isCollapsed || sel.rangeCount === 0) return

    const text = sel.toString()
    if (text.trim().length < 3) return

    const range = sel.getRangeAt(0)
    const rect = range.getBoundingClientRect()

    // Capture the surrounding paragraph text and the current page path at
    // selection time — stored with the highlight so the saved-highlights page
    // can show context and navigate back without re-fetching the source.
    const contextSnippet = captureContextFromSelection(text.trim())
    const sourceUrl = window.location.pathname
    const anchor = findSegmentAnchor(range, text.trim())

    onTextSelected(text, rect, contextSnippet, sourceUrl, anchor?.segmentIndex ?? null, anchor?.occurrence ?? null)
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault()
      // Text selection is only triggered by mouseUp; keyboard selection support would require
      // accessing the user's selection object, which is the same as the mouseUp handler
    }
  }

  return (
    <div role="button" tabIndex={0} onKeyDown={handleKeyDown} onMouseUp={handleMouseUp}>
      {children}

      {selection && !response && (
        <HighlightPopup
          alreadySaved={existing?.saved_for_revision ?? false}
          anchor={selection}
          initialNote={existing?.note ?? ""}
          isLoading={isLoading}
          // Remounts per distinct selection so the note textarea's local
          // state (seeded from initialNote) resets instead of leaking the
          // previous selection's note into a newly selected sentence.
          key={selection.text}
          onClose={onClose}
          onExplain={onExplain}
          onSave={onSaveRevision}
        />
      )}

      {response && (
        <ExplanationPanel
          initialNote={note}
          isLoading={isLoading}
          key={response.highlight_id}
          response={response}
          savedForRevision={savedForRevision}
          onClose={onClose}
          onToggleSaved={onToggleSaved}
        />
      )}
    </div>
  )
}
