"use client"

import React from "react"
import dynamic from "next/dynamic"
import { useTheme } from "next-themes"
import { Skeleton } from "@/components/ui/skeleton"
import { Textarea } from "@/components/ui/textarea"
import { cn } from "@/lib/utils"

const MonacoEditor = dynamic(
  async () => {
    // Configure the loader instance re-exported by @monaco-editor/react —
    // importing @monaco-editor/loader separately can resolve to a second
    // module instance under pnpm, leaving the react package's own loader on
    // its default CDN paths (which then 404/503s offline).
    const { default: monacoReact, loader } = await import("@monaco-editor/react")
    loader.config({ paths: { vs: "/monaco-vs" } })
    return monacoReact
  },
  {
    ssr: false,
    loading: () => <Skeleton className="h-full w-full rounded-md" />,
  },
)

interface CodeEditorProps {
  language?: string
  value?: string
  onChange?: (value: string | undefined) => void
  readOnly?: boolean
  height?: string | number
  fontSize?: number
  tabSize?: number
  wordWrap?: boolean
  minimap?: boolean
  className?: string
}

interface BoundaryState {
  failed: boolean
}

// Catches dynamic import failures and render errors from MonacoEditor.
// Falls back to a plain <Textarea> so the user can still write code.
class EditorErrorBoundary extends React.Component<
  React.PropsWithChildren<{ fallback: React.ReactNode }>,
  BoundaryState
> {
  constructor(props: React.PropsWithChildren<{ fallback: React.ReactNode }>) {
    super(props)
    this.state = { failed: false }
  }

  static getDerivedStateFromError(): BoundaryState {
    return { failed: true }
  }

  render() {
    if (this.state.failed) return this.props.fallback
    return this.props.children
  }
}

export function CodeEditor({
  language = "python",
  value = "",
  onChange,
  readOnly = false,
  height = "400px",
  fontSize = 14,
  tabSize = 4,
  wordWrap = true,
  minimap = false,
  className,
}: CodeEditorProps) {
  // Monaco is client-only (ssr: false), so resolvedTheme is always settled
  // by the time the editor paints — no light/dark flash.
  const { resolvedTheme } = useTheme()
  const fallback = (
    <Textarea
      className={cn(
        "h-full w-full resize-none font-mono text-sm",
        className,
      )}
      placeholder={`Write your ${language} code here…`}
      readOnly={readOnly}
      spellCheck={false}
      // eslint-disable-next-line no-restricted-syntax -- dynamic editor fallback height
      style={{ height }}
      value={value}
      onChange={(e) => onChange?.(e.target.value)}
    />
  )

  return (
    <EditorErrorBoundary fallback={fallback}>
      <div
        className={className}
        // eslint-disable-next-line no-restricted-syntax -- dynamic editor container height
        style={{ height }}>
        <MonacoEditor
          height="100%"
          language={language}
          options={{
            readOnly,
            fontSize,
            fontFamily: "var(--font-jetbrains-mono), 'JetBrains Mono', monospace",
            minimap: { enabled: minimap },
            scrollBeyondLastLine: false,
            // Monaco captures the wheel event even once its own content is
            // fully scrolled, so the page never receives it — this lets
            // scroll hand off to the page at the editor's scroll boundary.
            scrollbar: { alwaysConsumeMouseWheel: false },
            lineNumbers: "on",
            tabSize,
            wordWrap: wordWrap ? "on" : "off",
            padding: { top: 12, bottom: 12 },
            renderLineHighlight: "all",
            smoothScrolling: true,
            // Suggest/hover widgets render inside the editor's own DOM by
            // default, so any ancestor with overflow-hidden (e.g. the
            // rounded-lg panel this sits in) clips them to invisible. This
            // makes Monaco attach them to <body> with fixed positioning instead.
            fixedOverflowWidgets: true,
          }}
          theme={resolvedTheme === "light" ? "light" : "vs-dark"}
          value={value}
          onChange={onChange}
        />
      </div>
    </EditorErrorBoundary>
  )
}
