"use client"

import { useState } from "react"
import { RotateCcw } from "lucide-react"
import { Button } from "@/components/ui/button"
import { CodeEditor } from "@/components/shared/code-editor"
import type { LabCodeLanguage } from "@/lib/labs"

const LANGUAGES: { value: LabCodeLanguage; label: string }[] = [
  { value: "javascript", label: "JavaScript" },
  { value: "python", label: "Python" },
  { value: "typescript", label: "TypeScript" },
]

const FONT_MIN = 12
const FONT_MAX = 20
const STARTER_CODE: Record<LabCodeLanguage, string> = {
  javascript: "// Write your solution here\n\n",
  python: "# Write your solution here\n\n",
  typescript: "// Write your solution here\n\n",
}

interface LabCodePanelProps {
  code: string
  language: LabCodeLanguage
  onCodeChange: (value: string) => void
  onLanguageChange: (lang: LabCodeLanguage) => void
}

export function LabCodePanel({
  code,
  language,
  onCodeChange,
  onLanguageChange,
}: LabCodePanelProps) {
  const [fontSize, setFontSize] = useState(14)

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-2 border-b border-border px-3 py-2 shrink-0 bg-card">
        <label htmlFor="lab-language" className="sr-only">
          Language
        </label>
        <select
          id="lab-language"
          value={language}
          onChange={(e) => onLanguageChange(e.target.value as LabCodeLanguage)}
          className="text-xs bg-background border border-border rounded-md px-2 py-1 text-foreground focus:outline-none focus:ring-1 focus:ring-primary"
        >
          {LANGUAGES.map((l) => (
            <option key={l.value} value={l.value}>
              {l.label}
            </option>
          ))}
        </select>

        <div className="mx-2 h-4 w-px bg-border shrink-0" aria-hidden />

        <div className="flex items-center gap-1" aria-label="Font size">
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="h-6 w-6 p-0 text-xs font-bold text-muted-foreground"
            onClick={() => setFontSize((s) => Math.max(FONT_MIN, s - 1))}
            disabled={fontSize <= FONT_MIN}
            aria-label="Decrease font size"
          >
            A
          </Button>
          <span className="text-xs text-muted-foreground tabular-nums w-6 text-center select-none">
            {fontSize}
          </span>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="h-6 w-6 p-0 text-sm font-bold text-muted-foreground"
            onClick={() => setFontSize((s) => Math.min(FONT_MAX, s + 1))}
            disabled={fontSize >= FONT_MAX}
            aria-label="Increase font size"
          >
            A
          </Button>
        </div>

        <div className="mx-2 h-4 w-px bg-border shrink-0" aria-hidden />

        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="h-6 w-6 p-0 text-muted-foreground hover:text-foreground"
          onClick={() => onCodeChange(STARTER_CODE[language])}
          aria-label="Reset code to starter template"
          title="Reset code"
        >
          <RotateCcw className="h-3.5 w-3.5" aria-hidden />
        </Button>
      </div>

      <div className="flex-1 min-h-0">
        <CodeEditor
          language={language}
          value={code}
          fontSize={fontSize}
          onChange={(v) => onCodeChange(v ?? "")}
          height="100%"
        />
      </div>
    </div>
  )
}
