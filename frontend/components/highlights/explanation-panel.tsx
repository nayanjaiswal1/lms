"use client"

import { useState } from "react"
import { toast } from "sonner"
import { Sparkles, BookmarkPlus, BookmarkCheck, Copy, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Textarea } from "@/components/ui/textarea"
import { LessonFloatingPanel } from "@/components/shared/lesson-floating-panel"
import { MermaidDiagram } from "@/components/highlights/mermaid-diagram"
import type { ExplainResponse } from "@/lib/server/highlights"

interface ExplanationPanelProps {
  response: ExplainResponse
  savedForRevision: boolean
  initialNote: string
  isLoading: boolean
  moduleTitle: string
  lessonUrl: string
  onToggleSaved: (save: boolean, note?: string) => void
  onClose: () => void
}

export function ExplanationPanel({
  response,
  savedForRevision,
  initialNote,
  isLoading,
  moduleTitle,
  lessonUrl,
  onToggleSaved,
  onClose,
}: ExplanationPanelProps) {
  const [note, setNote] = useState(initialNote)
  const explanation = response.explanation
  if (!explanation) return null

  // Captured as plain strings (not read off `explanation` inside the
  // closure below) because TS can't carry the `if (!explanation) return
  // null` narrowing into a nested `function` declaration.
  const { selected_text: selectedText, explanation: explanationText } = explanation

  // Replaces the old standalone "Ask your AI" panel — same context blob,
  // now built from the highlight actually being explained instead of a
  // generic "help me with this lesson" prompt, and copied from right where
  // the student is already looking instead of a separate top-level button.
  async function copyPrompt() {
    const blob = [
      `I'm looking at the MindForge lesson "${moduleTitle}" (${lessonUrl}).`,
      `I highlighted this part: "${selectedText}"`,
      `MindForge's built-in AI explained it as:\n${explanationText}`,
      "Can you help me go deeper on this?",
    ].join("\n\n")
    await navigator.clipboard.writeText(blob)
    toast.success("Copied — paste it into your connected AI.")
  }

  return (
    <LessonFloatingPanel
      ariaLabel="AI Explanation"
      footer={
        <>
          <span className="text-xs text-muted-foreground">
            {explanation.serve_count > 1
              ? `Viewed ${explanation.serve_count} times`
              : "First explanation"}
          </span>
          <div className="flex items-center gap-1.5">
            <Button
              aria-label="Copy prompt for your AI"
              className="gap-1.5 text-xs h-8 px-3 touch-target"
              size="sm"
              variant="outline"
              onClick={copyPrompt}
            >
              <Copy aria-hidden className="size-3.5" />
              Copy prompt
            </Button>
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
        </>
      }
      headerExtra={
        <>
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
        </>
      }
      icon={<Sparkles aria-hidden className="size-4 text-ai" />}
      title="AI Explanation"
      onClose={onClose}
    >
      {/* Selected text + explanation — the only unbounded-length part
          (explanation.explanation is LLM-generated), so this is the one
          section that scrolls; header/note/footer stay put and reachable
          instead of getting pushed off-screen by a long explanation. */}
      <div className="min-h-0 flex-1 overflow-y-auto">
        <div className="px-4 pt-3">
          <p className="text-sm text-muted-foreground font-mono leading-relaxed line-clamp-2">
            &ldquo;{explanation.selected_text}&rdquo;
          </p>
        </div>

        <div className="px-4 py-3 flex flex-col gap-3">
          <p className="text-sm leading-relaxed text-foreground">{explanation.explanation}</p>
          {explanation.diagram && <MermaidDiagram chart={explanation.diagram} />}
        </div>
      </div>

      <div className="shrink-0 px-4 pb-3">
        <Textarea
          aria-label="Add a note to this highlight"
          className="min-h-0 h-14 resize-none text-xs"
          disabled={isLoading}
          placeholder="Add a note (optional)"
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
      </div>
    </LessonFloatingPanel>
  )
}
