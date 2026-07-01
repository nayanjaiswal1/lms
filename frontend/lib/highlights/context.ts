// Utilities for capturing surrounding context from a browser text selection.
// Called client-side at mouseup time so the context is captured fresh.

const BLOCK_TAGS = new Set(["p", "li", "h1", "h2", "h3", "h4", "h5", "blockquote", "td", "th", "pre"])
const CONTEXT_WINDOW = 130 // chars before and after the selection

// captureContextFromSelection extracts the surrounding paragraph text for a
// selection that is already live in the browser. Returns a trimmed snippet
// with ellipsis markers where the snippet was cut short.
export function captureContextFromSelection(selectedText: string): string {
  const sel = window.getSelection()
  if (!sel || sel.rangeCount === 0) return ""

  const range = sel.getRangeAt(0)

  // Walk up from the anchor node to the nearest block-level element.
  let node: Node | null = range.commonAncestorContainer
  while (node && node.nodeType !== Node.ELEMENT_NODE) {
    node = node.parentNode
  }
  while (node && node.parentNode) {
    const tag = (node as Element).tagName?.toLowerCase() ?? ""
    if (BLOCK_TAGS.has(tag)) break
    node = node.parentNode
  }

  const blockText = ((node as Element)?.textContent ?? "").replace(/\s+/g, " ").trim()
  if (!blockText) return ""

  const selLower = selectedText.toLowerCase()
  const blockLower = blockText.toLowerCase()
  const idx = blockLower.indexOf(selLower)

  // If the selected text fills most of the block, return the block as-is.
  if (idx === -1 || blockText.length <= selectedText.length + 40) {
    return blockText.slice(0, 400)
  }

  const start = Math.max(0, idx - CONTEXT_WINDOW)
  const end = Math.min(blockText.length, idx + selectedText.length + CONTEXT_WINDOW)
  const snippet = blockText.slice(start, end)

  return (start > 0 ? "…" : "") + snippet + (end < blockText.length ? "…" : "")
}
