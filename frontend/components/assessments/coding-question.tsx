"use client";

import * as React from "react";
import { cn } from "@/lib/utils";
import styles from "./coding-question.module.css";
import type { StudentCodingContent } from "@/lib/assessments/types";
import type { CodingAnswer } from "@/lib/assessments/use-answers";

interface CodingQuestionProps {
  content: StudentCodingContent;
  value: CodingAnswer | undefined;
  onLanguage: (language: string, starter: string) => void;
  onCode: (code: string, language: string) => void;
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

// CodingQuestion uses a LeetCode-style split panel: the left panel shows the
// problem description, constraints, and sample cases; the right panel is a dark
// monospace editor with line numbers, Tab-key indent, and language tab selection.
// The editor uses a CSS module for the dark theme because Tailwind cannot express
// hardcoded hex values in JSX class names (ESLint rule).
export function CodingQuestion({ content, value, onLanguage, onCode }: CodingQuestionProps) {
  const language = value?.language ?? content.languages[0] ?? "python";
  const code = value?.code ?? content.starter_code?.[language] ?? "";

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

  const lineCount = Math.max(code.split("\n").length, 20);
  const lineNumbers = Array.from({ length: lineCount }, (_, i) => i + 1).join("\n");

  return (
    <div className="flex min-h-[520px] flex-col overflow-hidden rounded-[--radius-lg] border border-border lg:min-h-[640px] lg:flex-row">

      {/* ── Left panel: problem description ──────────────────────────────── */}
      <div className="flex flex-col gap-5 overflow-y-auto border-b border-border p-5 lg:w-[42%] lg:border-b-0 lg:border-r">

        {/* Problem statement */}
        <div>
          <p className="whitespace-pre-wrap text-sm leading-relaxed">{content.prompt}</p>
        </div>

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

      {/* ── Right panel: editor ──────────────────────────────────────────── */}
      <div className="flex min-h-[300px] flex-1 flex-col lg:min-h-0">

        {/* Editor toolbar: language tabs + line count */}
        <div className="flex items-center justify-between border-b border-border bg-muted/50 px-3 py-1.5">
          <div className="flex gap-0.5">
            {content.languages.map((lang) => (
              <button
                key={lang}
                type="button"
                onClick={() => onLanguage(lang, content.starter_code?.[lang] ?? "")}
                className={cn(
                  "rounded px-3 py-1 text-xs font-medium transition-colors",
                  language === lang
                    ? "bg-background text-foreground shadow-sm"
                    : "text-muted-foreground hover:text-foreground",
                )}
              >
                {LANG_LABEL[lang] ?? lang}
              </button>
            ))}
          </div>
          <span className="text-xs text-muted-foreground tabular-nums">
            {code.split("\n").length} lines
          </span>
        </div>

        {/* Dark code editor with gutter */}
        <div className={styles.editorWrap}>
          <div ref={lineNumRef} className={styles.lineNums} aria-hidden>
            {lineNumbers}
          </div>
          <textarea
            ref={textareaRef}
            aria-label="Code editor"
            className={styles.editor}
            placeholder={`# Write your ${LANG_LABEL[language] ?? language} solution here…`}
            spellCheck={false}
            value={code}
            onChange={(e) => onCode(e.target.value, language)}
            onKeyDown={handleKeyDown}
            onScroll={handleScroll}
          />
        </div>
      </div>
    </div>
  );
}
