"use client"

import { useHighlightFlow } from "@/hooks/use-highlight-flow"
import { captureContextFromSelection } from "@/lib/highlights/context"
import { HighlightPopup } from "./highlight-popup"
import { ExplanationPanel } from "./explanation-panel"
import type { HighlightSourceType } from "@/lib/server/highlights"

interface HighlightProviderProps {
  children: React.ReactNode
  sourceType: HighlightSourceType
  sourceId: string
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
}: HighlightProviderProps) {
  const {
    selection,
    response,
    savedForRevision,
    isLoading,
    onTextSelected,
    onSaveRevision,
    onExplain,
    onToggleSaved,
    onClose,
  } = useHighlightFlow(sourceType, sourceId)

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

    onTextSelected(text, rect, contextSnippet, sourceUrl)
  }

  return (
    <div onMouseUp={handleMouseUp}>
      {children}

      {selection && !response && (
        <HighlightPopup
          anchor={selection}
          isLoading={isLoading}
          onSave={onSaveRevision}
          onExplain={onExplain}
          onClose={onClose}
        />
      )}

      {response && (
        <ExplanationPanel
          response={response}
          savedForRevision={savedForRevision}
          isLoading={isLoading}
          onToggleSaved={onToggleSaved}
          onClose={onClose}
        />
      )}
    </div>
  )
}
