"use client";

import * as React from "react";
import { Loader2, Play } from "lucide-react";
import { cn } from "@/lib/utils";
import styles from "./coding-question.module.css";
import { PromptRenderer } from "@/components/shared/prompt-renderer";
import { CodingConsole } from "@/components/assessments/coding-console";
import { ResizablePanelGroup, ResizablePanel, ResizableHandle } from "@/components/ui/resizable";
import { runCodeAction } from "@/app/(app)/assessments/[id]/take/actions";
import { SESSION_SUPERSEDED_MESSAGE } from "@/lib/assessments/types";
import type { RunResult, StudentCodingContent } from "@/lib/assessments/types";
import type { CodingAnswer } from "@/lib/assessments/use-answers";

interface CodingQuestionProps {
  content: StudentCodingContent;
  value: CodingAnswer | undefined;
  attemptId: string;
  sessionToken: string;
  assessmentQuestionId: string;
  onLanguage: (language: string, starter: string) => void;
  onCode: (code: string, language: string) => void;
  onSuperseded: () => void;
}

interface RunState {
  tab: "testcase" | "result";
  running: boolean;
  result: RunResult | null;
  error: string | null;
}

const LANG_LABEL: Record<string, string> = {
  python: "Python",
  javascript: "JavaScript",
  typescript: "TypeScript",
  go: "Go",
  java: "Java",
  cpp: "C++",
  c: "C",
  rust: "Rust",
};

// CodingQuestion uses a LeetCode-style split panel, draggable via the same
// react-resizable-panels wrapper the labs feature already uses (see
// lab-container-workspace.tsx / sandbox-workspace.tsx): an outer horizontal
// group divides problem prompt from editor+console, an inner vertical group
// divides the editor from the console. The left panel shows the problem
// description, constraints, and sample cases; the right panel is a dark
// monospace editor with line numbers, Tab-key indent, language tab selection,
// a Run button, and a console (Testcase/Result tabs) below the editor. Run only
// ever executes against non-hidden sample cases via runCodeAction — it never
// affects grading, which happens exclusively at final Submit.
// The editor uses a CSS module for the dark theme because Tailwind cannot express
// hardcoded hex values in JSX class names (ESLint rule).
export function CodingQuestion({
  content,
  value,
  attemptId,
  sessionToken,
  assessmentQuestionId,
  onLanguage,
  onCode,
  onSuperseded,
}: CodingQuestionProps) {
  const language = value?.language ?? content.languages[0] ?? "python";
  const code = value?.code ?? content.starter_code?.[language] ?? "";

  const [run, setRun] = React.useState<RunState>({
    tab: "testcase",
    running: false,
    result: null,
    error: null,
  });

  const textareaRef = React.useRef<HTMLTextAreaElement>(null);
  const lineNumRef = React.useRef<HTMLDivElement>(null);
  const pendingCursor = React.useRef<number | null>(null);

  // Sync line-number gutter scroll with the editor scroll
  const handleScroll = (e: React.UIEvent<HTMLTextAreaElement>) => {
    if (lineNumRef.current) {
      lineNumRef.current.scrollTop = e.currentTarget.scrollTop;
    }
  };

  // Tab key → insert 2 spaces instead of moving focus
  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key !== "Tab") return;
    e.preventDefault();
    const el = e.currentTarget;
    const start = el.selectionStart;
    const end = el.selectionEnd;
    const next = code.slice(0, start) + "  " + code.slice(end);
    pendingCursor.current = start + 2;
    onCode(next, language);
  };

  // Restore cursor position after the controlled value update following Tab press
  React.useEffect(() => {
    if (pendingCursor.current !== null && textareaRef.current) {
      const pos = pendingCursor.current;
      textareaRef.current.selectionStart = pos;
      textareaRef.current.selectionEnd = pos;
      pendingCursor.current = null;
    }
  }, [code]);

  const handleRun = async () => {
    setRun((prev) => ({ ...prev, tab: "result", running: true, error: null }));
    const res = await runCodeAction(attemptId, sessionToken, assessmentQuestionId, language, code);
    if (res.error === SESSION_SUPERSEDED_MESSAGE) {
      onSuperseded();
      return;
    }
    if (!res.ok || !res.data) {
      setRun((prev) => ({ ...prev, running: false, result: null, error: res.error ?? "Could not run your code." }));
      return;
    }
    setRun((prev) => ({ ...prev, running: false, result: res.data ?? null, error: null }));
  };

  const lineCount = Math.max(code.split("\n").length, 20);
  const lineNumbers = Array.from({ length: lineCount }, (_, i) => i + 1).join("\n");

  return (
    <div className="h-full overflow-hidden rounded-[--radius-lg] border border-border">
      <ResizablePanelGroup orientation="horizontal">

        {/* ── Left panel: problem description ────────────────────────────── */}
        <ResizablePanel defaultSize="42%" id="coding-question-prompt" maxSize="65%" minSize="25%">
          <div className="flex h-full flex-col gap-5 overflow-y-auto p-5">

            {/* Problem statement */}
            <PromptRenderer text={content.prompt} textClassName="text-sm leading-relaxed" />

            {/* Sample cases */}
            {content.sample_cases.length > 0 && (
              <div className="flex flex-col gap-4">
                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                  Examples
                </p>
                {content.sample_cases.map((c, i) => (
                  <div className="flex flex-col gap-2" key={i}>
                    <p className="text-xs font-medium text-muted-foreground">Example {i + 1}</p>
                    <div className="rounded-[--radius-md] bg-muted p-3">
                      <p className="mb-1 text-xs text-muted-foreground">Input</p>
                      <pre className="overflow-x-auto font-mono text-xs text-foreground">{c.stdin}</pre>
                    </div>
                    <div className="rounded-[--radius-md] bg-muted p-3">
                      <p className="mb-1 text-xs text-muted-foreground">Output</p>
                      <pre className="overflow-x-auto font-mono text-xs text-foreground">{c.expected}</pre>
                    </div>
                  </div>
                ))}
              </div>
            )}

            {/* Constraints */}
            <div className="flex flex-col gap-2">
              <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                Constraints
              </p>
              <ul className="flex flex-col gap-1.5 text-xs text-muted-foreground">
                <li>
                  Time limit:{" "}
                  <span className="font-mono text-foreground">{content.time_limit_ms} ms</span>
                </li>
                <li>
                  Memory:{" "}
                  <span className="font-mono text-foreground">
                    {Math.round(content.memory_limit_kb / 1024)} MB
                  </span>
                </li>
                {content.hidden_count > 0 && (
                  <li>
                    {content.hidden_count} hidden test case
                    {content.hidden_count > 1 ? "s" : ""} (graded)
                  </li>
                )}
              </ul>
            </div>
          </div>
        </ResizablePanel>

        <ResizableHandle withHandle orientation="horizontal" />

        {/* ── Right panel: editor + run console ──────────────────────────── */}
        <ResizablePanel defaultSize="58%" id="coding-question-editor" minSize="35%">
          <ResizablePanelGroup orientation="vertical">
            <ResizablePanel defaultSize="70%" id="coding-question-editor-pane" minSize="30%">
              <div className="flex h-full flex-col">

                {/* Editor toolbar: language tabs + Run button + line count */}
                <div className="flex items-center justify-between border-b border-border bg-muted/50 px-3 py-1.5">
                  <div className="flex gap-0.5">
                    {content.languages.map((lang) => (
                      <button
                        className={cn(
                          "rounded px-3 py-1 text-xs font-medium transition-colors",
                          language === lang
                            ? "bg-background text-foreground shadow-sm"
                            : "text-muted-foreground hover:text-foreground",
                        )}
                        key={lang}
                        type="button"
                        onClick={() => onLanguage(lang, content.starter_code?.[lang] ?? "")}
                      >
                        {LANG_LABEL[lang] ?? lang}
                      </button>
                    ))}
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-xs text-muted-foreground tabular-nums">
                      {code.split("\n").length} lines
                    </span>
                    <button
                      aria-label="Run code against sample tests"
                      className="flex h-7 items-center gap-1.5 rounded px-2.5 text-xs font-medium text-ai transition-colors hover:bg-ai/10 disabled:cursor-not-allowed disabled:text-muted-foreground disabled:hover:bg-transparent"
                      disabled={run.running || !code.trim() || content.sample_cases.length === 0}
                      type="button"
                      onClick={() => void handleRun()}
                    >
                      {run.running ? (
                        <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />
                      ) : (
                        <Play aria-hidden className="h-3.5 w-3.5" />
                      )}
                      Run
                    </button>
                  </div>
                </div>

                {/* Dark code editor with gutter */}
                <div className={styles.editorWrap}>
                  <div aria-hidden className={styles.lineNums} ref={lineNumRef}>
                    {lineNumbers}
                  </div>
                  <textarea
                    aria-label="Code editor"
                    className={styles.editor}
                    placeholder={`# Write your ${LANG_LABEL[language] ?? language} solution here…`}
                    ref={textareaRef}
                    spellCheck={false}
                    value={code}
                    onChange={(e) => onCode(e.target.value, language)}
                    onKeyDown={handleKeyDown}
                    onScroll={handleScroll}
                  />
                </div>
              </div>
            </ResizablePanel>

            <ResizableHandle withHandle orientation="vertical" />

            <ResizablePanel defaultSize="30%" id="coding-question-console" minSize="15%">
              {/* Run console — Testcase / Result tabs */}
              <CodingConsole
                error={run.error}
                result={run.result}
                running={run.running}
                sampleCases={content.sample_cases}
                tab={run.tab}
                onTabChange={(tab) => setRun((prev) => ({ ...prev, tab }))}
              />
            </ResizablePanel>
          </ResizablePanelGroup>
        </ResizablePanel>
      </ResizablePanelGroup>
    </div>
  );
}
