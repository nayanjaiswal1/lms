import Link from "next/link"
import { BookmarkCheck, ExternalLink, FileX, Sparkles } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { getMyHighlights } from "@/lib/server/highlights"
import type { Highlight } from "@/lib/server/highlights"
import { getCurrentUser } from "@/lib/server/auth"
import ROUTES from "@/lib/routes"
import { cn } from "@/lib/utils"

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

      {/* Personal note */}
      {highlight.note && (
        <div className="rounded-lg border border-primary/30 bg-primary/5 p-3">
          <div className="flex items-center gap-1.5 mb-1">
            <BookmarkCheck aria-hidden className="size-3.5 text-primary shrink-0" />
            <span className="text-xs font-medium text-primary">Your note</span>
          </div>
          <p className="text-xs leading-relaxed text-foreground whitespace-pre-wrap">
            {highlight.note}
          </p>
        </div>
      )}

      {/* AI explanation */}
      {highlight.explanation && (
        <div className="ai-surface rounded-lg p-3">
          <div className="flex items-center gap-1.5 mb-2">
            <Sparkles aria-hidden className="size-3.5 text-ai shrink-0" />
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
          <Badge className="text-xs" variant="secondary">
            {sourceLabel}
          </Badge>
          <time
            className="text-xs text-muted-foreground"
            dateTime={highlight.created_at}
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
            aria-label="Source content was deleted"
            className="gap-1 text-xs text-muted-foreground"
            variant="secondary"
          >
            <FileX aria-hidden className="size-3" />
            Source deleted
          </Badge>
        ) : highlight.source_url ? (
          <Button
            asChild
            className="gap-1.5 text-xs h-7 px-2 touch-target text-muted-foreground hover:text-foreground"
            size="sm"
            variant="ghost"
          >
            <Link href={highlight.source_url}>
              <ExternalLink aria-hidden className="size-3" />
              Go to {sourceLabel.toLowerCase()}
            </Link>
          </Button>
        ) : null}
      </div>
    </article>
  )
}

export default async function SavedHighlightsPage() {
  const [highlights, user] = await Promise.all([getMyHighlights(true), getCurrentUser()])
  const isSuperAdmin = user?.platform_role === "super_admin"

  return (
    <main className="page-container-sm py-8">
      <div className="page-header">
        <div className="flex items-center gap-3">
          <BookmarkCheck aria-hidden className="size-6 text-primary" />
          <h1 className="page-title">Saved Highlights</h1>
        </div>
        <span className="text-sm text-muted-foreground">
          {highlights.length} saved
        </span>
      </div>

      {isSuperAdmin && (
        <div aria-label="Highlights view" className="flex gap-1 border-b border-border mb-6" role="tablist">
          <span
            aria-selected="true"
            className="px-3 py-2 text-sm font-medium border-b-2 border-primary text-foreground"
            role="tab"
          >
            My Saved
          </span>
          <Link
            aria-selected="false"
            className={cn(
              "px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors",
              "border-transparent text-muted-foreground hover:text-foreground",
            )}
            href={ROUTES.PLATFORM_HIGHLIGHTS}
            role="tab"
          >
            Confusing Content (Platform)
          </Link>
        </div>
      )}

      {highlights.length === 0 ? (
        <div className="empty-state py-16">
          <BookmarkCheck aria-hidden className="size-10 text-muted-foreground mb-4" />
          <p className="text-muted-foreground text-center">
            No saved highlights yet.
            <br />
            Select any text while studying and click &ldquo;Save for revision&rdquo;.
          </p>
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {highlights.map((h) => (
            <HighlightCard highlight={h} key={h.id} />
          ))}
        </div>
      )}
    </main>
  )
}
