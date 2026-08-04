"use client"

import { useState } from "react"
import { createPortal } from "react-dom"
import { BookmarkPlus, BookmarkCheck, Sparkles, X, Loader2, FileText } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Textarea } from "@/components/ui/textarea"
import { useClickOutside } from "@/hooks/use-click-outside"

interface Anchor {
  top: number
  left: number
  width: number
}

interface HighlightPopupProps {
  anchor: Anchor
  isLoading: boolean
  // True when this exact selection was already saved for revision elsewhere
  // on the page. Only changes the Save/Update label + icon and the note
  // indicator line below — the card's theme stays identical either way.
  // The place a user should visually recognize "I've flagged this before" is
  // the inline mark left on the sentence itself, not this popup.
  alreadySaved: boolean
  initialNote: string
  onSave: (note: string) => void
  onExplain: () => void
  onClose: () => void
}

// Portaled to <body> and positioned absolute (not fixed) using document-
// relative coordinates (anchor.top/left already include scrollY/scrollX —
// see HighlightProvider) — so the popup scrolls along with the selected text
// instead of staying pinned to the viewport while the page moves under it.
// translate-x-[-50%] centres the popup on the anchor midpoint.
// translate-y-[calc(-100%-8px)] lifts it fully above the selection with 8px gap.
export function HighlightPopup({
  anchor,
  isLoading,
  alreadySaved,
  initialNote,
  onSave,
  onExplain,
  onClose,
}: HighlightPopupProps) {
  const [note, setNote] = useState(initialNote)
  const midX = anchor.left + anchor.width / 2
  const ref = useClickOutside<HTMLDivElement>(onClose)

  return createPortal(
    <div
      className="absolute z-dropdown"
      ref={ref}
      style={
        {
          "--popup-top": `${anchor.top}px`,
          "--popup-left": `${midX}px`,
          top: "var(--popup-top)",
          left: "var(--popup-left)",
          transform: "translate(-50%, calc(-100% - 8px))",
        } as React.CSSProperties
      }
    >
      <div className="card-raised flex w-full sm:w-80 flex-col gap-2.5 rounded-xl p-2.5 animate-in fade-in slide-in-from-bottom-2 duration-fast">
        {initialNote && (
          <div className="flex items-center gap-1.5 px-1 text-xs text-muted-foreground">
            <FileText aria-hidden className="size-3.5 shrink-0" />
            Note already saved for this selection
          </div>
        )}

        <Textarea
          aria-label="Add a note to this highlight"
          className="min-h-0 h-16 resize-none text-xs"
          disabled={isLoading}
          placeholder="Add a note (optional)"
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />

        <div className="flex items-center gap-1">
          <Button
            aria-label={alreadySaved ? "Update saved highlight" : "Save selection for revision"}
            className="gap-1.5 text-xs h-8 px-3 touch-target flex-1"
            disabled={isLoading}
            size="sm"
            variant="ghost"
            onClick={() => onSave(note)}
          >
            {isLoading ? (
              <Loader2 aria-hidden className="size-3.5 animate-spin" />
            ) : alreadySaved ? (
              <BookmarkCheck aria-hidden className="size-3.5" />
            ) : (
              <BookmarkPlus aria-hidden className="size-3.5" />
            )}
            {alreadySaved ? "Update" : "Save"}
          </Button>

          <div aria-hidden className="w-px h-5 bg-border shrink-0" />

          <Button
            aria-label="Explain this selection with AI"
            className="gap-1.5 text-xs h-8 px-3 touch-target flex-1 bg-ai text-ai-foreground hover:bg-ai/90"
            disabled={isLoading}
            size="sm"
            onClick={onExplain}
          >
            {isLoading ? (
              <Loader2 aria-hidden className="size-3.5 animate-spin" />
            ) : (
              <Sparkles aria-hidden className="size-3.5" />
            )}
            Explain
          </Button>

          <Button
            aria-label="Dismiss"
            className="size-8 touch-target shrink-0"
            size="icon"
            variant="ghost"
            onClick={onClose}
          >
            <X aria-hidden className="size-3.5" />
          </Button>
        </div>
      </div>

      {/* Caret pointing at the selection the popup is anchored to. */}
      <div
        aria-hidden
        className="absolute left-1/2 top-full size-2.5 -translate-x-1/2 -translate-y-1/2 rotate-45 border-b border-r border-border bg-card"
      />
    </div>,
    document.body,
  )
}
