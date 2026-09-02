"use client";

import { useRef, useState, useTransition, type PointerEvent, type ReactNode } from "react";
import { Copy, Loader2, Play, RotateCcw, X } from "lucide-react";
import { toast } from "sonner";
import { runSnippetAction } from "@/app/(app)/courses/actions";
import type { SnippetResult } from "@/app/(app)/courses/actions";
import { CodeEditor } from "@/components/shared/code-editor";
import { Button } from "@/components/ui/button";
import { isRunCombo, useKeyboardShortcut } from "@/hooks/use-keyboard-shortcut";
import { RUNNABLE_LANGUAGES } from "@/lib/courses/runnable-languages";
import { cn } from "@/lib/utils";

interface LessonCodeRunnerProps {
  language: string;
  initialCode: string;
  /** Editor floor in lines — the solve page wants a tall LeetCode-style editor. */
  minLines?: number;
  /** Stretches the editor to the height of its container instead of sizing to line count — used inside LabFixedConsole, where the panel itself provides the height. */
  fill?: boolean;
  /** Replaces the static language label in the header with a caller-owned control (see LessonCodeBlock's language switcher). Falls back to plain text when omitted. */
  languageSwitcher?: ReactNode;
}

const OUTPUT_MIN_HEIGHT = 80;
const OUTPUT_MAX_HEIGHT = 480;
const OUTPUT_DEFAULT_HEIGHT = 224;

// Interactive code block for lesson content: the snippet from the lesson is
// editable and runnable in place (feature 2). Runs go through the session-less
// snippet endpoint — no lab session, no scoring, just stdout/stderr.
export function LessonCodeRunner({ language, initialCode, minLines = 4, fill = false, languageSwitcher }: LessonCodeRunnerProps) {
  const lang = language.trim().toLowerCase();
  const [code, setCode] = useState(initialCode);
  const [result, setResult] = useState<SnippetResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isRunning, startRun] = useTransition();
  const [outputHeight, setOutputHeight] = useState(OUTPUT_DEFAULT_HEIGHT);
  const outputDrag = useRef<{ startY: number; startHeight: number } | null>(null);

  const isDirty = code !== initialCode;
  const editorLines = Math.min(Math.max(code.split("\n").length, minLines), Math.max(24, minLines));

  function run() {
    setError(null);
    startRun(async () => {
      const res = await runSnippetAction(lang, code);
      if (!res.ok || !res.data) {
        setError(res.error ?? "Run failed. Please try again.");
        return;
      }
      setResult(res.data);
    });
  }

  function reset() {
    setCode(initialCode);
    setResult(null);
    setError(null);
  }

  function closeOutput() {
    setResult(null);
    setError(null);
  }

  async function copyCode() {
    await navigator.clipboard.writeText(code);
    toast.success("Code copied to clipboard.");
  }

  function onOutputDragStart(e: PointerEvent<HTMLDivElement>) {
    outputDrag.current = { startY: e.clientY, startHeight: outputHeight };
    e.currentTarget.setPointerCapture(e.pointerId);
  }

  function onOutputDragMove(e: PointerEvent<HTMLDivElement>) {
    if (!outputDrag.current) return;
    const delta = outputDrag.current.startY - e.clientY;
    setOutputHeight(
      Math.min(OUTPUT_MAX_HEIGHT, Math.max(OUTPUT_MIN_HEIGHT, outputDrag.current.startHeight + delta)),
    );
  }

  function onOutputDragEnd() {
    outputDrag.current = null;
  }

  useKeyboardShortcut(!isRunning, isRunCombo, run);
  useKeyboardShortcut(!!(error ?? result), (e) => e.key === "Escape", closeOutput);

  return (
    <div className={cn("overflow-hidden rounded-lg border border-border bg-card", fill && "flex h-full flex-col")}>
      <div className="flex shrink-0 items-center gap-2 border-b border-border px-3 py-1.5">
        {languageSwitcher ?? (
          <span className="text-xs font-semibold text-muted-foreground">
            {RUNNABLE_LANGUAGES[lang] ?? language}
          </span>
        )}
        <div className="ml-auto flex items-center gap-1">
          <Button
            aria-label="Copy code"
            className="touch-target text-muted-foreground"
            size="icon"
            variant="ghost"
            onClick={copyCode}
          >
            <Copy aria-hidden className="h-3.5 w-3.5" />
          </Button>
          {isDirty && (
            <Button
              aria-label="Reset code"
              className="touch-target text-muted-foreground"
              size="icon"
              variant="ghost"
              onClick={reset}
            >
              <RotateCcw aria-hidden className="h-3.5 w-3.5" />
            </Button>
          )}
          <Button
            disabled={isRunning}
            size="sm"
            title="Run (Ctrl+Enter)"
            variant="secondary"
            onClick={run}
          >
            {isRunning ? (
              <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />
            ) : (
              <Play aria-hidden className="h-3.5 w-3.5" />
            )}
            Run
          </Button>
        </div>
      </div>

      {fill ? (
        <div className="min-h-0 flex-1">
          <CodeEditor
            height="100%"
            language={lang === "python3" ? "python" : lang}
            value={code}
            onChange={(value) => setCode(value ?? "")}
          />
        </div>
      ) : (
        <CodeEditor
          height={`${editorLines * 1.5}rem`}
          language={lang === "python3" ? "python" : lang}
          value={code}
          onChange={(value) => setCode(value ?? "")}
        />
      )}

      {(error ?? result) && (
        <>
          <div
            aria-label="Resize output panel"
            className="h-1.5 shrink-0 cursor-ns-resize touch-none bg-transparent transition-colors duration-fast hover:bg-primary/30"
            role="separator"
            onPointerDown={onOutputDragStart}
            onPointerMove={onOutputDragMove}
            onPointerUp={onOutputDragEnd}
          />
          <div
            className="flex shrink-0 flex-col border-t border-border"
            // eslint-disable-next-line no-restricted-syntax -- dynamic drag-resized output height
            style={{ height: outputHeight }}
          >
            <div className="flex shrink-0 items-center gap-2 px-3 py-1.5">
              <span className="text-xs font-semibold text-muted-foreground">Output</span>
              <Button
                aria-label="Close output"
                className="touch-target ml-auto text-muted-foreground"
                size="icon"
                title="Close output (Esc)"
                variant="ghost"
                onClick={closeOutput}
              >
                <X aria-hidden className="h-3.5 w-3.5" />
              </Button>
            </div>
            <div className="min-h-0 flex-1 overflow-auto px-3 pb-2">
              {error ? (
                <p className="text-xs text-destructive">{error}</p>
              ) : result ? (
                <div className="flex flex-col gap-2">
                  {result.stdout && (
                    <pre className="whitespace-pre-wrap break-words font-mono text-xs text-foreground">
                      {result.stdout}
                    </pre>
                  )}
                  {result.stderr && (
                    <pre className="whitespace-pre-wrap break-words font-mono text-xs text-destructive">
                      {result.stderr}
                    </pre>
                  )}
                  {!result.stdout && !result.stderr && (
                    <p className="text-xs text-muted-foreground">
                      {result.exit_ok ? "Ran successfully — no output." : "Exited with an error — no output."}
                    </p>
                  )}
                </div>
              ) : null}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
