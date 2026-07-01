"use client"

import { Sparkles, BookmarkPlus, BookmarkCheck, X, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { cn } from "@/lib/utils"
import type { ExplainResponse } from "@/lib/server/highlights"

interface ExplanationPanelProps {
  response: ExplainResponse
  savedForRevision: boolean
  isLoading: boolean
  onToggleSaved: (save: boolean) => void
  onClose: () => void
}

export function ExplanationPanel({
  response,
  savedForRevision,
  isLoading,
  onToggleSaved,
  onClose,
}: ExplanationPanelProps) {
  const explanation = response.explanation
  if (!explanation) return null

  return (
    <div
      className={cn(
        "fixed bottom-4 inset-x-4 sm:inset-x-auto sm:right-4 sm:left-auto sm:w-full sm:max-w-sm z-modal",
        "animate-in slide-in-from-bottom-4 fade-in duration-normal ease-smooth",
      )}
      role="dialog"
      aria-label="AI Explanation"
    >
      <div className="ai-surface rounded-xl shadow-raised overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-border">
          <div className="flex items-center gap-2">
            <Sparkles className="size-4 text-ai" aria-hidden />
            <span className="text-sm font-medium">AI Explanation</span>
            {explanation.from_cache && (
              <Badge variant="secondary" className="text-xs h-5 px-1.5">
                Cached
              </Badge>
            )}
          </div>
          <Button
            size="icon"
            variant="ghost"
            className="size-7 touch-target"
            onClick={onClose}
            aria-label="Close explanation"
          >
            <X className="size-3.5" aria-hidden />
          </Button>
        </div>

        {/* Selected text */}
        <div className="px-4 pt-3">
          <p className="text-xs text-muted-foreground font-mono leading-relaxed line-clamp-2">
            &ldquo;{explanation.selected_text}&rdquo;
          </p>
        </div>

        {/* Explanation body */}
        <div className="px-4 py-3">
          <p className="text-sm leading-relaxed text-foreground">{explanation.explanation}</p>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-4 py-3 border-t border-border">
          <span className="text-xs text-muted-foreground">
            {explanation.serve_count > 1
              ? `Viewed ${explanation.serve_count} times`
              : "First explanation"}
          </span>
          <Button
            size="sm"
            variant={savedForRevision ? "secondary" : "outline"}
            className={cn(
              "gap-1.5 text-xs h-8 px-3 touch-target",
              savedForRevision && "text-primary border-primary",
            )}
            onClick={() => onToggleSaved(!savedForRevision)}
            disabled={isLoading}
            aria-label={savedForRevision ? "Remove from revision" : "Save for revision"}
          >
            {isLoading ? (
              <Loader2 className="size-3.5 animate-spin" aria-hidden />
            ) : savedForRevision ? (
              <BookmarkCheck className="size-3.5" aria-hidden />
            ) : (
              <BookmarkPlus className="size-3.5" aria-hidden />
            )}
            {savedForRevision ? "Saved" : "Save for revision"}
          </Button>
        </div>
      </div>
    </div>
  )
}
