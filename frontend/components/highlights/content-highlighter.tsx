"use client"

import { useEffect, useRef } from "react"
import { cn } from "@/lib/utils"
import type { Highlight } from "@/lib/server/highlights"

interface ContentHighlighterProps {
  // Raw HTML string (e.g. from TipTap / wiki pages / lesson bodies).
  html: string
  highlights: Highlight[]
  className?: string
}

// Renders HTML content and overlays visual marks on previously highlighted text.
// Uses TreeWalker to find text nodes and wrap matches in <mark> elements —
// safe for arbitrary HTML because we never alter element structure, only split text nodes.
export function ContentHighlighter({
  html,
  highlights,
  className,
}: ContentHighlighterProps) {
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const container = containerRef.current
    if (!container || highlights.length === 0) return

    // Reset any previous marks (idempotent re-apply).
    container.querySelectorAll("mark[data-mf-highlight]").forEach((el) => {
      const parent = el.parentNode
      if (!parent) return
      parent.replaceChild(document.createTextNode(el.textContent ?? ""), el)
    })
    container.normalize()

    // Collect all text nodes inside the container.
    const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT)
    const textNodes: Text[] = []
    let node = walker.nextNode()
    while (node) {
      textNodes.push(node as Text)
      node = walker.nextNode()
    }

    // Sort highlights longest-first so longer phrases win over sub-phrase matches.
    const texts = highlights
      .map((h) => h.selected_text)
      .filter((t) => t.trim().length > 0)
      .sort((a, b) => b.length - a.length)

    for (const textNode of textNodes) {
      const content = textNode.nodeValue ?? ""
      if (!content.trim()) continue

      for (const text of texts) {
        const idx = content.toLowerCase().indexOf(text.toLowerCase())
        if (idx === -1) continue

        // Split into before / mark / after and re-attach.
        const before = document.createTextNode(content.slice(0, idx))
        const mark = document.createElement("mark")
        mark.setAttribute("data-mf-highlight", "")
        // Use Tailwind-compatible class names that map to CSS vars — no raw colors.
        mark.className =
          "bg-primary/15 text-foreground rounded-sm px-px cursor-pointer transition-colors duration-fast hover:bg-primary/30"
        mark.textContent = content.slice(idx, idx + text.length)
        const after = document.createTextNode(content.slice(idx + text.length))

        const parent = textNode.parentNode
        if (!parent) continue
        parent.insertBefore(before, textNode)
        parent.insertBefore(mark, textNode)
        parent.insertBefore(after, textNode)
        parent.removeChild(textNode)
        break // one match per text node; walker snapshot is already collected
      }
    }
  }, [highlights])

  return (
    <div
      ref={containerRef}
      className={cn("prose-content", className)}
      // eslint-disable-next-line no-restricted-syntax -- rendering server-provided rich-text HTML
      dangerouslySetInnerHTML={{ __html: html }}
    />
  )
}
