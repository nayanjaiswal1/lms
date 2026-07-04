"use client"

import { CheckCircle2, XCircle, Save, ShieldCheck } from "lucide-react"
import { Button } from "@/components/ui/button"
import { ScrollArea } from "@/components/ui/scroll-area"
import { CodeEditor } from "@/components/shared/code-editor"
import { LabFileTabs } from "@/components/labs/lab-file-tabs"
import { useLabSaveShortcut } from "@/hooks/use-lab-save-shortcut"
import { cn } from "@/lib/utils"
import type { ValidateResult } from "@/lib/labs/files"

interface OpenFile {
  path: string
  content: string
  dirty: boolean
}

interface LabFileEditorProps {
  openFiles: OpenFile[]
  activePath: string | null
  validateResult: ValidateResult | null
  isSaving: boolean
  onSelectTab: (path: string) => void
  onCloseTab: (path: string) => void
  onChange: (content: string) => void
  onSave: () => void
  onValidate: () => void
}

function languageForPath(path: string): string {
  if (path.endsWith(".json")) return "json"
  if (path.endsWith(".sh")) return "shell"
  return "yaml"
}

export function LabFileEditor({
  openFiles,
  activePath,
  validateResult,
  isSaving,
  onSelectTab,
  onCloseTab,
  onChange,
  onSave,
  onValidate,
}: LabFileEditorProps) {
  const active = openFiles.find((f) => f.path === activePath) ?? null

  useLabSaveShortcut(!!active, onSave)

  return (
    <div className="flex flex-col h-full">
      <LabFileTabs activePath={activePath} openFiles={openFiles} onClose={onCloseTab} onSelect={onSelectTab} />

      {!active ? (
        <div className="flex flex-1 items-center justify-center text-sm text-muted-foreground">
          Select a file to edit, or create a new one.
        </div>
      ) : (
        <>
          <div className="flex items-center justify-between gap-2 px-3 py-2 border-b border-border shrink-0">
            <span className="text-sm font-mono truncate text-foreground">
              {active.path}
              {active.dirty && <span className="text-primary"> •</span>}
            </span>
            <div className="flex items-center gap-2 shrink-0">
              <Button
                className="gap-1.5 h-7 text-xs"
                disabled={isSaving}
                size="sm"
                variant="outline"
                onClick={onValidate}
              >
                <ShieldCheck aria-hidden className="h-3.5 w-3.5" />
                Validate
              </Button>
              <Button
                className="gap-1.5 h-7 text-xs"
                disabled={isSaving || !active.dirty}
                size="sm"
                onClick={onSave}
              >
                <Save aria-hidden className="h-3.5 w-3.5" />
                {isSaving ? "Saving…" : "Save"}
              </Button>
            </div>
          </div>

          <div className="flex-1 min-h-0">
            <CodeEditor
              height="100%"
              language={languageForPath(active.path)}
              value={active.content}
              onChange={(v) => onChange(v ?? "")}
            />
          </div>

          {validateResult && (
            <div className="border-t border-border shrink-0 max-h-40">
              <ScrollArea className="h-40">
                <div className="p-3 flex flex-col gap-2">
                  <div
                    className={cn(
                      "flex items-center gap-1.5 text-xs font-medium",
                      validateResult.valid ? "text-success" : "text-destructive",
                    )}
                  >
                    {validateResult.valid ? (
                      <CheckCircle2 aria-hidden className="h-3.5 w-3.5" />
                    ) : (
                      <XCircle aria-hidden className="h-3.5 w-3.5" />
                    )}
                    {validateResult.valid ? "Valid manifest" : "Validation failed"}
                  </div>
                  {(validateResult.stdout || validateResult.stderr) && (
                    <pre className="text-xs font-mono whitespace-pre-wrap text-muted-foreground bg-muted rounded-md p-2">
                      {validateResult.stdout}
                      {validateResult.stderr}
                    </pre>
                  )}
                </div>
              </ScrollArea>
            </div>
          )}
        </>
      )}
    </div>
  )
}
