"use client"

import { useEffect, useId, useState } from "react"
import { useTheme } from "next-themes"
import { Skeleton } from "@/components/ui/skeleton"

interface MermaidDiagramProps {
  chart: string
}

// Literal colors matching MindForge's design tokens (globals.css), not CSS
// var() references — Mermaid's theme engine runs real color math (lighten/
// darken via khroma) on these strings at init time, which throws on an
// unresolvable `var(--x)` reference. Two static palettes, swapped on
// resolvedTheme, is the correct way to theme it; a live CSS variable is not.
const LIGHT_THEME_VARIABLES = {
  fontFamily: "var(--font-plus-jakarta), ui-sans-serif, sans-serif",
  fontSize: "14px",
  background: "transparent",
  primaryColor: "hsl(193, 60%, 94%)",
  primaryTextColor: "hsl(25, 15%, 10%)",
  primaryBorderColor: "hsl(193, 82%, 31%)",
  lineColor: "hsl(25, 8%, 44%)",
  secondaryColor: "hsl(34, 12%, 93%)",
  secondaryBorderColor: "hsl(30, 10%, 91%)",
  tertiaryColor: "hsl(36, 15%, 99%)",
  tertiaryBorderColor: "hsl(30, 10%, 91%)",
  mainBkg: "hsl(193, 60%, 94%)",
  nodeBorder: "hsl(193, 82%, 31%)",
  clusterBkg: "hsl(34, 12%, 93%)",
  clusterBorder: "hsl(30, 10%, 91%)",
  titleColor: "hsl(25, 15%, 10%)",
  edgeLabelBackground: "hsl(36, 15%, 99%)",
  textColor: "hsl(25, 15%, 10%)",
  nodeTextColor: "hsl(25, 15%, 10%)",
}

const DARK_THEME_VARIABLES = {
  ...LIGHT_THEME_VARIABLES,
  primaryColor: "hsl(193, 40%, 14%)",
  primaryTextColor: "hsl(30, 8%, 97%)",
  primaryBorderColor: "hsl(187, 85%, 53%)",
  lineColor: "hsl(28, 6%, 60%)",
  secondaryColor: "hsl(20, 7%, 11%)",
  secondaryBorderColor: "hsl(20, 7%, 19%)",
  tertiaryColor: "hsl(20, 8%, 8%)",
  tertiaryBorderColor: "hsl(20, 7%, 19%)",
  mainBkg: "hsl(193, 40%, 14%)",
  nodeBorder: "hsl(187, 85%, 53%)",
  clusterBkg: "hsl(20, 7%, 11%)",
  clusterBorder: "hsl(20, 7%, 19%)",
  titleColor: "hsl(30, 8%, 97%)",
  edgeLabelBackground: "hsl(20, 8%, 8%)",
  textColor: "hsl(30, 8%, 97%)",
  nodeTextColor: "hsl(30, 8%, 97%)",
}

// Rounded nodes, thinner lines, no drop shadow — reads as one clean diagram
// instead of mermaid's boxy stock look. Plain CSS, not consumed by khroma,
// so literal-vs-var() doesn't matter here.
const THEME_CSS = `
  .node rect, .node polygon, .node circle, .node path { rx: 10px; ry: 10px; }
  .node .label { font-weight: 500; }
  .edgePath .path { stroke-width: 1.5px; }
  .edgeLabel { border-radius: 6px; }
`

// Mermaid is loaded on demand via a plain dynamic import — only explanations
// the AI decided actually warrant a flowchart include a `chart`, so most
// explanations never pull this in at all. securityLevel "strict" sanitizes
// node labels, since the diagram source is LLM-generated text.
export function MermaidDiagram({ chart }: MermaidDiagramProps) {
  const id = useId().replace(/:/g, "")
  const { resolvedTheme } = useTheme()
  const [svg, setSvg] = useState<string | null>(null)
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    let cancelled = false
    setSvg(null)
    setFailed(false)

    async function run() {
      try {
        const { default: mermaid } = await import("mermaid")
        mermaid.initialize({
          startOnLoad: false,
          theme: "base",
          themeVariables: resolvedTheme === "dark" ? DARK_THEME_VARIABLES : LIGHT_THEME_VARIABLES,
          themeCSS: THEME_CSS,
          securityLevel: "strict",
          flowchart: {
            curve: "basis",
            padding: 18,
            nodeSpacing: 45,
            rankSpacing: 55,
            useMaxWidth: true,
          },
        })
        const { svg: rendered } = await mermaid.render(`mermaid-${id}`, chart)
        if (!cancelled) setSvg(rendered)
      } catch (err) {
        // ponytail: AI-generated Mermaid syntax occasionally fails to parse —
        // the explanation text still stands alone, so drop the diagram
        // silently instead of showing a broken box. Logged so a real bug in
        // the theme config (vs. bad AI output) is still catchable in devtools.
        console.error("MermaidDiagram: render failed", err)
        if (!cancelled) setFailed(true)
      }
    }

    run()
    return () => {
      cancelled = true
    }
  }, [chart, id, resolvedTheme])

  if (failed) return null
  if (!svg) return <Skeleton className="h-32 w-full rounded-lg" />

  return (
    <div
      aria-label="AI-generated flowchart"
      className="ai-surface rounded-lg p-4 [&_svg]:h-auto [&_svg]:max-w-full"
      dangerouslySetInnerHTML={{ __html: svg }}
    />
  )
}
