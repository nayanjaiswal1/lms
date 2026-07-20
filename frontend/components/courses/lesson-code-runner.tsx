"use client";

import { useState, useTransition } from "react";
import { Loader2, Play, RotateCcw } from "lucide-react";
import { runSnippetAction } from "@/app/(app)/courses/actions";
import type { SnippetResult } from "@/app/(app)/courses/actions";
import { CodeEditor } from "@/components/shared/code-editor";
import { Button } from "@/components/ui/button";
import { RUNNABLE_LANGUAGES } from "@/lib/courses/runnable-languages";

interface LessonCodeRunnerProps {
  language: string;
  initialCode: string;
  /** Editor floor in lines — the solve page wants a tall LeetCode-style editor. */
  minLines?: number;
}

// Interactive code block for lesson content: the snippet from the lesson is
// editable and runnable in place (feature 2). Runs go through the session-less
// snippet endpoint — no lab session, no scoring, just stdout/stderr.
export function LessonCodeRunner({ language, initialCode, minLines = 4 }: LessonCodeRunnerProps) {
  const lang = language.trim().toLowerCase();
  const [code, setCode] = useState(initialCode);
  const [result, setResult] = useState<SnippetResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isRunning, startRun] = useTransition();

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

  return (
    <div className="overflow-hidden rounded-lg border border-border bg-card">
      <div className="flex items-center gap-2 border-b border-border px-3 py-1.5">
        <span className="text-xs font-semibold text-muted-foreground">
          {RUNNABLE_LANGUAGES[lang] ?? language}
        </span>
        <div className="ml-auto flex items-center gap-1">
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
          <Button disabled={isRunning} size="sm" variant="secondary" onClick={run}>
            {isRunning ? (
              <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />
            ) : (
              <Play aria-hidden className="h-3.5 w-3.5" />
            )}
            Run
          </Button>
        </div>
      </div>

      <CodeEditor
        height={`${editorLines * 1.5}rem`}
        language={lang === "python3" ? "python" : lang}
        value={code}
        onChange={(value) => setCode(value ?? "")}
      />

      {(error ?? result) && (
        <div className="border-t border-border px-3 py-2">
          {error ? (
            <p className="text-xs text-destructive">{error}</p>
          ) : result ? (
            <div className="flex flex-col gap-2">
              {result.stdout && (
                <pre className="max-h-48 overflow-auto whitespace-pre-wrap break-words font-mono text-xs text-foreground">
                  {result.stdout}
                </pre>
              )}
              {result.stderr && (
                <pre className="max-h-48 overflow-auto whitespace-pre-wrap break-words font-mono text-xs text-destructive">
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
      )}
    </div>
  );
}
