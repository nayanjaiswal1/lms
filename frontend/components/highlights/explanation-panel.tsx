"use client"

import { useState } from "react"
import { Sparkles, BookmarkPlus, BookmarkCheck, X, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Textarea } from "@/components/ui/textarea"
import { cn } from "@/lib/utils"
import type { ExplainResponse } from "@/lib/server/highlights"

interface ExplanationPanelProps {
  response: ExplainResponse
  savedForRevision: boolean
  initialNote: string
  isLoading: boolean
  onToggleSaved: (save: boolean, note?: string) => void
  onClose: () => void
}

export function ExplanationPanel({
  response,
  savedForRevision,
  initialNote,
  isLoading,
  onToggleSaved,
  onClose,
}: ExplanationPanelProps) {
  const [note, setNote] = useState(initialNote)
  const explanation = response.explanation
  if (!explanation) return null

  return (
    <div
      aria-label="AI Explanation"
      className={cn(
        "fixed bottom-4 inset-x-4 sm:inset-x-auto sm:right-4 sm:left-auto sm:w-full sm:max-w-sm z-modal",
        "animate-in slide-in-from-bottom-4 fade-in duration-normal ease-smooth",
      )}
      role="dialog"
    >
      <div className="ai-surface rounded-xl shadow-raised overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-border">
          <div className="flex items-center gap-2">
            <Sparkles aria-hidden className="size-4 text-ai" />
            <span className="text-sm font-medium">AI Explanation</span>
            {explanation.from_cache && (
              <Badge className="text-xs h-5 px-1.5" variant="secondary">
                Cached
              </Badge>
            )}
            {savedForRevision && (
              <Badge className="gap-1 text-xs h-5 px-1.5" variant="secondary">
                <BookmarkCheck aria-hidden className="size-3" />
                Saved
              </Badge>
            )}
          </div>
          <Button
            aria-label="Close explanation"
            className="size-7 touch-target"
            size="icon"
            variant="ghost"
            onClick={onClose}
          >
            <X aria-hidden className="size-3.5" />
          </Button>
        </div>

        {/* Selected text */}
        <div className="px-4 pt-3">
          <p className="text-sm text-muted-foreground font-mono leading-relaxed line-clamp-2">
            &ldquo;{explanation.selected_text}&rdquo;
          </p>
        </div>

        {/* Explanation body */}
        <div className="px-4 py-3">
          <p className="text-sm leading-relaxed text-foreground">{explanation.explanation}</p>
        </div>

        {/* Note */}
        <div className="px-4 pb-3">
          <Textarea
            aria-label="Add a note to this highlight"
            className="min-h-0 h-14 resize-none text-xs"
            disabled={isLoading}
            placeholder="Add a note (optional)"
            value={note}
            onChange={(e) => setNote(e.target.value)}
          />
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-4 py-3 border-t border-border">
          <span className="text-xs text-muted-foreground">
            {explanation.serve_count > 1
              ? `Viewed ${explanation.serve_count} times`
              : "First explanation"}
          </span>
          <Button
            aria-label={savedForRevision ? "Remove from revision" : "Save for revision"}
            className="gap-1.5 text-xs h-8 px-3 touch-target"
            disabled={isLoading}
            size="sm"
            variant="outline"
            onClick={() => onToggleSaved(!savedForRevision, note)}
          >
            {isLoading ? (
              <Loader2 aria-hidden className="size-3.5 animate-spin" />
            ) : savedForRevision ? (
              <BookmarkCheck aria-hidden className="size-3.5" />
            ) : (
              <BookmarkPlus aria-hidden className="size-3.5" />
            )}
            {savedForRevision ? "Saved" : "Save for revision"}
          </Button>
        </div>
      </div>
    </div>
  )
}
