"use client"

import { BookmarkCheck, BookmarkPlus, FileX, Loader2, Sparkles } from "lucide-react"
import { useTransition } from "react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet"
import { cn } from "@/lib/utils"
import { toggleRevisionAction } from "@/app/(app)/highlights/actions"
import type { Highlight } from "@/lib/server/highlights"

interface HighlightsSheetProps {
  open: boolean
  highlights: Highlight[]
  onClose: () => void
  onHighlightUpdated: (updated: Highlight) => void
}

const SOURCE_LABEL: Record<string, string> = {
  wiki_page: "Wiki",
  lesson: "Lesson",
  problem: "Problem",
}

function HighlightRow({
  highlight,
  onUpdated,
}: {
  highlight: Highlight
  onUpdated: (h: Highlight) => void
}) {
  const [isPending, startTransition] = useTransition()

  function toggle(save: boolean) {
    startTransition(async () => {
      const result = await toggleRevisionAction(highlight.id, save)
      if (result.ok && result.data) {
        onUpdated(result.data)
        toast.success(save ? "Saved for revision" : "Removed from revision")
      } else {
        toast.error(result.error ?? "Failed to update")
      }
    })
  }

  return (
    <article className="border-b border-border last:border-0 py-4 flex flex-col gap-3">
      {/* Selected text */}
      <blockquote className="text-sm font-medium leading-relaxed text-foreground">
        &ldquo;{highlight.selected_text}&rdquo;
      </blockquote>

      {/* AI explanation */}
      {highlight.explanation && (
        <div className="ai-surface rounded-lg p-3">
          <div className="flex items-center gap-1.5 mb-1.5">
            <Sparkles className="size-3 text-ai shrink-0" aria-hidden />
            <span className="text-xs font-medium text-ai">AI</span>
            {highlight.explanation.from_cache && (
              <Badge variant="secondary" className="text-xs h-4 px-1">cached</Badge>
            )}
          </div>
          <p className="text-xs leading-relaxed text-foreground">
            {highlight.explanation.explanation}
          </p>
        </div>
      )}

      {/* Footer row */}
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <span className="text-xs text-muted-foreground">
            {SOURCE_LABEL[highlight.source_type] ?? highlight.source_type} ·{" "}
            {new Date(highlight.created_at).toLocaleDateString("en-US", {
              month: "short",
              day: "numeric",
            })}
          </span>
          {highlight.source_orphaned && (
            <Badge
              variant="secondary"
              className="gap-1 text-xs text-muted-foreground"
              aria-label="Source content was deleted"
            >
              <FileX className="size-3" aria-hidden />
              Deleted
            </Badge>
          )}
        </div>

        <Button
          size="sm"
          variant={highlight.saved_for_revision ? "secondary" : "ghost"}
          className={cn(
            "gap-1.5 text-xs h-7 px-2 touch-target",
            highlight.saved_for_revision && "text-primary",
          )}
          onClick={() => toggle(!highlight.saved_for_revision)}
          disabled={isPending}
          aria-label={
            highlight.saved_for_revision ? "Remove from revision" : "Save for revision"
          }
        >
          {isPending ? (
            <Loader2 className="size-3 animate-spin" aria-hidden />
          ) : highlight.saved_for_revision ? (
            <BookmarkCheck className="size-3" aria-hidden />
          ) : (
            <BookmarkPlus className="size-3" aria-hidden />
          )}
          {highlight.saved_for_revision ? "Saved" : "Save"}
        </Button>
      </div>
    </article>
  )
}

export function HighlightsSheet({
  open,
  highlights,
  onClose,
  onHighlightUpdated,
}: HighlightsSheetProps) {
  const savedCount = highlights.filter((h) => h.saved_for_revision).length

  return (
    <Sheet open={open} onOpenChange={(isOpen) => { if (!isOpen) onClose() }}>
      <SheetContent side="right" className="w-full sm:w-[400px] flex flex-col p-0">
        <SheetHeader className="px-5 py-4 border-b border-border shrink-0">
          <div className="flex items-center justify-between">
            <SheetTitle className="text-base">
              Highlights
              <Badge variant="secondary" className="ml-2 text-xs">
                {highlights.length}
              </Badge>
            </SheetTitle>
            {savedCount > 0 && (
              <span className="text-xs text-muted-foreground">
                {savedCount} saved for revision
              </span>
            )}
          </div>
        </SheetHeader>

        <div className="flex-1 overflow-y-auto px-5">
          {highlights.length === 0 ? (
            <div className="empty-state py-12">
              <p className="text-sm text-muted-foreground text-center">
                No highlights on this page yet.
                <br />
                Select any text to highlight it.
              </p>
            </div>
          ) : (
            highlights.map((h) => (
              <HighlightRow
                key={h.id}
                highlight={h}
                onUpdated={onHighlightUpdated}
              />
            ))
          )}
        </div>
      </SheetContent>
    </Sheet>
  )
}
