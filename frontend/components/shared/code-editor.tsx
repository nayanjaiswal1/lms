"use client"

import React from "react"
import dynamic from "next/dynamic"
import { Skeleton } from "@/components/ui/skeleton"
import { Textarea } from "@/components/ui/textarea"
import { cn } from "@/lib/utils"

const MonacoEditor = dynamic(
  async () => {
    const [{ default: loaderLib }, { default: monacoReact }] = await Promise.all([
      import("@monaco-editor/loader"),
      import("@monaco-editor/react"),
    ])
    loaderLib.config({ paths: { vs: "/monaco-vs" } })
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
  className,
}: CodeEditorProps) {
  const fallback = (
    <Textarea
      className={cn(
        "h-full w-full resize-none font-mono text-sm",
        className,
      )}
      style={{ height }}
      value={value}
      readOnly={readOnly}
      onChange={(e) => onChange?.(e.target.value)}
      placeholder={`Write your ${language} code here…`}
      spellCheck={false}
    />
  )

  return (
    <EditorErrorBoundary fallback={fallback}>
      <div className={className} style={{ height }}>
        <MonacoEditor
          height="100%"
          language={language}
          value={value}
          onChange={onChange}
          theme="vs-dark"
          options={{
            readOnly,
            fontSize,
            fontFamily: "var(--font-jetbrains-mono), 'JetBrains Mono', monospace",
            minimap: { enabled: false },
            scrollBeyondLastLine: false,
            lineNumbers: "on",
            tabSize: 4,
            wordWrap: "on",
            padding: { top: 12, bottom: 12 },
            renderLineHighlight: "all",
            smoothScrolling: true,
          }}
        />
      </div>
    </EditorErrorBoundary>
  )
}
