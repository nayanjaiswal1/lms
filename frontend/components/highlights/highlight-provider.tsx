"use client"

import { useQueryState } from "nuqs"
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
  // Passed through to the Explanation panel's "Copy prompt" button, which
  // copies a context blob for the student's own connected AI — same context
  // the old standalone "Ask your AI" button used to provide.
  moduleTitle: string
  lessonUrl: string
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
//
// Lesson notes and this highlight explain popup/panel are independent
// floating overlays rendered over the same lesson content. Neither used to
// know about the other, so opening one while the other was already open just
// stacked them on screen. They now share the `lessonPanel` URL param (read
// here via nuqs, written by LessonNotes) as a single slot: the popup/panel
// below only renders while Notes isn't open, matching this codebase's
// URL-driven-modal-state convention instead of a one-off React state/context
// just for this.
export function HighlightProvider({
  children,
  sourceType,
  sourceId,
  initialHighlights = [],
  moduleTitle,
  lessonUrl,
}: HighlightProviderProps) {
  const [lessonPanel] = useQueryState("lessonPanel")
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

  function handleMouseUp(e: React.MouseEvent) {
    // Selecting the AI's own answer text (e.g. to copy a phrase) fires this same
    // mouseup, since the floating panels render as descendants of this wrapper —
    // without this guard it would swap the open explanation for a new selection
    // popup instead of leaving the panel alone. LessonFloatingPanel's root marks
    // itself role="dialog" for exactly this check.
    if ((e.target as HTMLElement).closest('[role="dialog"]')) return

    const sel = window.getSelection()
    if (!sel || sel.isCollapsed || sel.rangeCount === 0) return

    const text = sel.toString()
    if (text.trim().length < 3) return

    const range = sel.getRangeAt(0)
    const viewportRect = range.getBoundingClientRect()
    // Stored as document-relative (not viewport-relative) coordinates so the
    // popup — positioned absolute, not fixed — stays glued to the selected
    // text as the page scrolls instead of staying put in the viewport.
    const rect = {
      top: viewportRect.top + window.scrollY,
      left: viewportRect.left + window.scrollX,
      width: viewportRect.width,
    }

    // Capture the surrounding paragraph text and the current page path at
    // selection time — stored with the highlight so the saved-highlights page
    // can show context and navigate back without re-fetching the source.
    const contextSnippet = captureContextFromSelection(text.trim())
    const sourceUrl = window.location.pathname
    const anchor = findSegmentAnchor(range, text.trim())

    onTextSelected(text, rect, contextSnippet, sourceUrl, anchor?.segmentIndex ?? null, anchor?.occurrence ?? null)
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    // Only relevant when this wrapper div itself is the focused element
    // (role="button" for a11y linting, since it has onMouseUp) — Enter/Space
    // there would otherwise scroll the page like a native button press.
    // Keydown events bubble from every descendant, including any <textarea>
    // in the lesson body or in the notes/ask-AI/explanation panels rendered
    // below; without this check, typing a space in any of them bubbled up
    // here and got preventDefault()-ed before the textarea could insert it.
    if (e.target !== e.currentTarget) return
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault()
      // Text selection is only triggered by mouseUp; keyboard selection support would require
      // accessing the user's selection object, which is the same as the mouseUp handler
    }
  }

  return (
    <div role="button" tabIndex={0} onKeyDown={handleKeyDown} onMouseUp={handleMouseUp}>
      {children}

      {selection && !response && !lessonPanel && (
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

      {response && !lessonPanel && (
        <ExplanationPanel
          initialNote={note}
          isLoading={isLoading}
          key={response.highlight_id}
          lessonUrl={lessonUrl}
          moduleTitle={moduleTitle}
          response={response}
          savedForRevision={savedForRevision}
          onClose={onClose}
          onToggleSaved={onToggleSaved}
        />
      )}
    </div>
  )
}
