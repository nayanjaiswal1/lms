import type { Highlight } from "@/lib/server/highlights"

function escapeAttr(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
}

// All non-overlapping case-insensitive occurrences of `needle` in `text`, in order.
function findOccurrences(text: string, needle: string): number[] {
  const lowerText = text.toLowerCase()
  const lowerNeedle = needle.toLowerCase()
  const indices: number[] = []
  let from = 0
  while (true) {
    const idx = lowerText.indexOf(lowerNeedle, from)
    if (idx === -1) return indices
    indices.push(idx)
    from = idx + lowerNeedle.length
  }
}

function wrapOccurrence(text: string, highlight: Highlight, idx: number): string {
  const before = text.slice(0, idx)
  const match = text.slice(idx, idx + highlight.selected_text.length)
  const after = text.slice(idx + highlight.selected_text.length)
  const titleAttr = highlight.note ? ` title="${escapeAttr(highlight.note)}"` : ""

  return `${before}<mark data-mf-highlight class="bg-primary/20 text-foreground rounded-sm px-px cursor-help"${titleAttr}>${match}</mark>${after}`
}

// Server-side (no client JS) overlay of previously saved highlights onto a
// lesson's rendered HTML, so a returning student instantly sees what they
// flagged before — hovering a mark shows its note via the native title tooltip.
// Only saved_for_revision highlights are marked; highlights created just by
// clicking "Explain" without saving aren't meant to persist as visible flags.
// Runs on plain text segments only (splits out tags first) so it can never
// match inside an attribute or corrupt the markup.
//
// A highlight is anchored to the segment it was created in (position_start)
// and which occurrence of its text within that segment it was (position_end,
// 0-based) — captured at selection time in use-highlight-flow.ts. Without
// that anchor, matching purely on selected_text would mark every identical
// sentence anywhere in the lesson. Highlights saved before anchoring existed
// have position_start === null; those fall back to "first occurrence in this
// segment" rather than being silently dropped.
export function markHighlightsInHtml(html: string, highlights: Highlight[], segmentIndex: number): string {
  const targets = highlights
    .filter((h) => h.saved_for_revision && h.selected_text.trim().length > 0)
    .filter((h) => h.position_start === null || h.position_start === segmentIndex)
    .map((h) => ({ highlight: h, occurrence: h.position_start === segmentIndex ? (h.position_end ?? 0) : 0 }))
    // Longest text first so a highlighted phrase wins over a highlighted sub-phrase it contains.
    .sort((a, b) => b.highlight.selected_text.length - a.highlight.selected_text.length)

  if (targets.length === 0) return html

  const consumed = new Map<Highlight, number>()

  return html
    .split(/(<[^>]+>)/g)
    .map((token) => {
      if (token.startsWith("<")) return token

      let marked: string | null = null
      for (const { highlight, occurrence } of targets) {
        const seen = consumed.get(highlight) ?? 0
        const positions = findOccurrences(token, highlight.selected_text)
        const localIndex = occurrence - seen
        // Only the first highlight (by sort order) whose target occurrence
        // falls in this token gets visually wrapped, matching the original
        // one-mark-per-token contract — but every highlight's running count
        // still advances so later tokens stay correctly indexed.
        if (marked === null && localIndex >= 0 && localIndex < positions.length) {
          marked = wrapOccurrence(token, highlight, positions[localIndex])
        }
        consumed.set(highlight, seen + positions.length)
      }
      return marked ?? token
    })
    .join("")
}
