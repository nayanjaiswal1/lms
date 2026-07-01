import Link from "next/link"
import { BookmarkCheck, ExternalLink, FileX, Sparkles } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { getMyHighlights } from "@/lib/server/highlights"
import type { Highlight } from "@/lib/server/highlights"

export const metadata = { title: "Saved Highlights — MindForge" }

const SOURCE_LABEL: Record<string, string> = {
  wiki_page: "Wiki",
  lesson: "Lesson",
  problem: "Problem",
}

// Renders the context_snippet with the selected_text visually marked inside it.
// Falls back to just the selected text when no snippet was captured.
function ContextBlock({ highlight }: { highlight: Highlight }) {
  const snippet = highlight.context_snippet
  const selected = highlight.selected_text

  if (!snippet) {
    return (
      <blockquote className="text-sm font-medium leading-relaxed text-foreground">
        &ldquo;{selected}&rdquo;
      </blockquote>
    )
  }

  // Find the selected text within the snippet (case-insensitive).
  const lower = snippet.toLowerCase()
  const selLower = selected.toLowerCase()
  const idx = lower.indexOf(selLower)

  if (idx === -1) {
    // Selected text not found in snippet — show both separately.
    return (
      <div className="flex flex-col gap-2">
        <p className="text-xs text-muted-foreground leading-relaxed">{snippet}</p>
        <blockquote className="text-sm font-medium leading-relaxed text-foreground border-l-2 border-primary pl-3">
          &ldquo;{selected}&rdquo;
        </blockquote>
      </div>
    )
  }

  const before = snippet.slice(0, idx)
  const match = snippet.slice(idx, idx + selected.length)
  const after = snippet.slice(idx + selected.length)

  return (
    <p className="text-sm leading-relaxed text-foreground">
      <span className="text-muted-foreground">{before}</span>
      <mark className="bg-primary/15 text-foreground rounded-sm px-0.5 font-medium not-italic">
        {match}
      </mark>
      <span className="text-muted-foreground">{after}</span>
    </p>
  )
}

function HighlightCard({ highlight }: { highlight: Highlight }) {
  const sourceLabel = SOURCE_LABEL[highlight.source_type] ?? highlight.source_type

  return (
    <article className="card-base p-5 flex flex-col gap-4">
      {/* Context block */}
      <ContextBlock highlight={highlight} />

      {/* AI explanation */}
      {highlight.explanation && (
        <div className="ai-surface rounded-lg p-3">
          <div className="flex items-center gap-1.5 mb-2">
            <Sparkles className="size-3.5 text-ai shrink-0" aria-hidden />
            <span className="text-xs font-medium text-ai">AI Explanation</span>
          </div>
          <p className="text-xs leading-relaxed text-foreground">
            {highlight.explanation.explanation}
          </p>
        </div>
      )}

      {/* Footer: source badge + date + navigation */}
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div className="flex items-center gap-2">
          <Badge variant="secondary" className="text-xs">
            {sourceLabel}
          </Badge>
          <time
            dateTime={highlight.created_at}
            className="text-xs text-muted-foreground"
          >
            {new Date(highlight.created_at).toLocaleDateString("en-US", {
              month: "short",
              day: "numeric",
              year: "numeric",
            })}
          </time>
        </div>

        {highlight.source_orphaned ? (
          <Badge
            variant="secondary"
            className="gap-1 text-xs text-muted-foreground"
            aria-label="Source content was deleted"
          >
            <FileX className="size-3" aria-hidden />
            Source deleted
          </Badge>
        ) : highlight.source_url ? (
          <Button
            asChild
            size="sm"
            variant="ghost"
            className="gap-1.5 text-xs h-7 px-2 touch-target text-muted-foreground hover:text-foreground"
          >
            <Link href={highlight.source_url}>
              <ExternalLink className="size-3" aria-hidden />
              Go to {sourceLabel.toLowerCase()}
            </Link>
          </Button>
        ) : null}
      </div>
    </article>
  )
}

export default async function SavedHighlightsPage() {
  const highlights = await getMyHighlights(true)

  return (
    <main className="page-container-sm py-8">
      <div className="page-header">
        <div className="flex items-center gap-3">
          <BookmarkCheck className="size-6 text-primary" aria-hidden />
          <h1 className="page-title">Saved Highlights</h1>
        </div>
        <span className="text-sm text-muted-foreground">
          {highlights.length} saved
        </span>
      </div>

      {highlights.length === 0 ? (
        <div className="empty-state py-16">
          <BookmarkCheck className="size-10 text-muted-foreground mb-4" aria-hidden />
          <p className="text-muted-foreground text-center">
            No saved highlights yet.
            <br />
            Select any text while studying and click &ldquo;Save for revision&rdquo;.
          </p>
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {highlights.map((h) => (
            <HighlightCard key={h.id} highlight={h} />
          ))}
        </div>
      )}
    </main>
  )
}
