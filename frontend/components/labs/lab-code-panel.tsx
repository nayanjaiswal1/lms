"use client"

import { useState } from "react"
import { RotateCcw, Columns2, Rows2, Loader2, CheckCircle2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { CodeEditor } from "@/components/shared/code-editor"
import { LabCodeConsole } from "@/components/labs/lab-code-console"
import {
  ResizablePanelGroup,
  ResizablePanel,
  ResizableHandle,
} from "@/components/ui/resizable"
import type { LabCodeLanguage } from "@/lib/labs"
import type { LabRunResult } from "@/hooks/use-lab-verify"

const LANGUAGES: { value: LabCodeLanguage; label: string }[] = [
  { value: "javascript", label: "JavaScript" },
  { value: "python", label: "Python" },
  { value: "typescript", label: "TypeScript" },
]

const LANGUAGE_LABELS: Record<LabCodeLanguage, string> = {
  javascript: "JavaScript",
  python: "Python",
  typescript: "TypeScript",
}

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
  isLanguageLocked: boolean
  onCodeChange: (value: string) => void
  onLanguageChange: (lang: LabCodeLanguage) => void
  lastRun: LabRunResult | null
  isVerifying: boolean
  taskId: string | undefined
  isTaskPassed: boolean
  onCheck: (taskId: string) => void
}

export function LabCodePanel({
  code,
  language,
  isLanguageLocked,
  onCodeChange,
  onLanguageChange,
  lastRun,
  isVerifying,
  taskId,
  isTaskPassed,
  onCheck,
}: LabCodePanelProps) {
  const [fontSize, setFontSize] = useState(14)
  const [consoleOrientation, setConsoleOrientation] = useState<"horizontal" | "vertical">(
    "vertical",
  )

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-2 border-b border-border px-3 py-2 shrink-0 bg-card">
        {isLanguageLocked ? (
          <span
            className="text-xs bg-muted rounded-md px-2 py-1 text-foreground font-medium"
            title="This lab's tasks are written for this language and cannot be changed"
          >
            {LANGUAGE_LABELS[language]}
          </span>
        ) : (
          <>
            <label className="sr-only" htmlFor="lab-language">
              Language
            </label>
            <select
              className="text-xs bg-background border border-border rounded-md px-2 py-1 text-foreground focus:outline-none focus:ring-1 focus:ring-primary"
              id="lab-language"
              value={language}
              onChange={(e) => onLanguageChange(e.target.value as LabCodeLanguage)}
            >
              {LANGUAGES.map((l) => (
                <option key={l.value} value={l.value}>
                  {l.label}
                </option>
              ))}
            </select>
          </>
        )}

        <div aria-hidden className="mx-2 h-4 w-px bg-border shrink-0" />

        <div aria-label="Font size" className="flex items-center gap-1">
          <Button
            aria-label="Decrease font size"
            className="h-6 w-6 p-0 text-xs font-bold text-muted-foreground"
            disabled={fontSize <= FONT_MIN}
            size="sm"
            type="button"
            variant="ghost"
            onClick={() => setFontSize((s) => Math.max(FONT_MIN, s - 1))}
          >
            A
          </Button>
          <span className="text-xs text-muted-foreground tabular-nums w-6 text-center select-none">
            {fontSize}
          </span>
          <Button
            aria-label="Increase font size"
            className="h-6 w-6 p-0 text-sm font-bold text-muted-foreground"
            disabled={fontSize >= FONT_MAX}
            size="sm"
            type="button"
            variant="ghost"
            onClick={() => setFontSize((s) => Math.min(FONT_MAX, s + 1))}
          >
            A
          </Button>
        </div>

        <div aria-hidden className="mx-2 h-4 w-px bg-border shrink-0" />

        <Button
          aria-label="Reset code to starter template"
          className="h-6 w-6 p-0 text-muted-foreground hover:text-foreground"
          size="sm"
          title="Reset code"
          type="button"
          variant="ghost"
          onClick={() => onCodeChange(STARTER_CODE[language])}
        >
          <RotateCcw aria-hidden className="h-3.5 w-3.5" />
        </Button>

        <div aria-hidden className="mx-2 h-4 w-px bg-border shrink-0" />

        <Button
          aria-label={
            consoleOrientation === "vertical"
              ? "Switch console to side-by-side layout"
              : "Switch console to stacked layout"
          }
          className="h-6 w-6 p-0 text-muted-foreground hover:text-foreground"
          size="sm"
          title="Switch layout"
          type="button"
          variant="ghost"
          onClick={() =>
            setConsoleOrientation((o) => (o === "vertical" ? "horizontal" : "vertical"))
          }
        >
          {consoleOrientation === "vertical" ? (
            <Columns2 aria-hidden className="h-3.5 w-3.5" />
          ) : (
            <Rows2 aria-hidden className="h-3.5 w-3.5" />
          )}
        </Button>

        {taskId && (
          <div className="ml-auto flex items-center shrink-0">
            {isTaskPassed ? (
              <div className="flex h-7 items-center gap-1.5 rounded-md border border-success/20 bg-success/10 px-2.5">
                <CheckCircle2 aria-hidden className="h-3.5 w-3.5 text-success shrink-0" />
                <span className="text-xs font-medium text-success whitespace-nowrap">Passed</span>
              </div>
            ) : (
              <Button
                aria-label={isVerifying ? "Verifying…" : "Check task"}
                className="h-7 gap-1.5"
                disabled={isVerifying}
                size="sm"
                onClick={() => onCheck(taskId)}
              >
                {isVerifying ? (
                  <>
                    <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />
                    Checking…
                  </>
                ) : (
                  "Check"
                )}
              </Button>
            )}
          </div>
        )}
      </div>

      <div className="flex-1 min-h-0">
        <ResizablePanelGroup orientation={consoleOrientation}>
          <ResizablePanel defaultSize="65%" id="lab-code-editor" minSize="30%">
            <CodeEditor
              fontSize={fontSize}
              height="100%"
              language={language}
              value={code}
              onChange={(v) => onCodeChange(v ?? "")}
            />
          </ResizablePanel>
          <ResizableHandle withHandle orientation={consoleOrientation} />
          <ResizablePanel defaultSize="35%" id="lab-code-console" minSize="15%">
            <LabCodeConsole isVerifying={isVerifying} result={lastRun} />
          </ResizablePanel>
        </ResizablePanelGroup>
      </div>
    </div>
  )
}
