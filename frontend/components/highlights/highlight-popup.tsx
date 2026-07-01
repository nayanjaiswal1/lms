"use client"

import { BookmarkPlus, Sparkles, X, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"

interface Anchor {
  top: number
  left: number
  width: number
}

interface HighlightPopupProps {
  anchor: Anchor
  isLoading: boolean
  onSave: () => void
  onExplain: () => void
  onClose: () => void
}

// Positioned fixed relative to the viewport, centered above the selection.
// translate-x-[-50%] centres the popup on the anchor midpoint.
// translate-y-[calc(-100%-8px)] lifts it fully above the selection with 8px gap.
export function HighlightPopup({
  anchor,
  isLoading,
  onSave,
  onExplain,
  onClose,
}: HighlightPopupProps) {
  const midX = anchor.left + anchor.width / 2

  return (
    // eslint-disable-next-line no-restricted-syntax -- dynamic positioning from DOMRect requires inline CSS vars
    <div
      className="fixed z-dropdown"
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
      <div className={cn(
        "card-raised flex items-center gap-1 p-1 rounded-xl",
        "animate-in fade-in slide-in-from-bottom-2 duration-fast",
      )}>
        <Button
          size="sm"
          variant="ghost"
          className="gap-1.5 text-xs h-8 px-3 touch-target"
          onClick={onSave}
          disabled={isLoading}
          aria-label="Save selection for revision"
        >
          <BookmarkPlus className="size-3.5" aria-hidden />
          Save
        </Button>

        <div className="w-px h-5 bg-border shrink-0" aria-hidden />

        <Button
          size="sm"
          className="gap-1.5 text-xs h-8 px-3 touch-target bg-ai text-ai-foreground hover:bg-ai/90"
          onClick={onExplain}
          disabled={isLoading}
          aria-label="Explain this selection with AI"
        >
          {isLoading ? (
            <Loader2 className="size-3.5 animate-spin" aria-hidden />
          ) : (
            <Sparkles className="size-3.5" aria-hidden />
          )}
          Explain
        </Button>

        <Button
          size="icon"
          variant="ghost"
          className="size-8 touch-target shrink-0"
          onClick={onClose}
          aria-label="Dismiss"
        >
          <X className="size-3.5" aria-hidden />
        </Button>
      </div>
    </div>
  )
}
