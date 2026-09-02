"use client";

import type { ReactNode } from "react";
import { Copy } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";

interface LessonStaticCodeBlockProps {
  language: string;
  code: string;
  /** Replaces the static language label in the header with a caller-owned control (see LessonCodeBlock's language switcher). Falls back to plain text when omitted. */
  languageSwitcher?: ReactNode;
}

// Chrome-matched sibling of LessonCodeRunner for languages that aren't
// runnable in-page (see isRunnableLanguage) — same header bar and copy
// button, no editor/run affordances since there's nothing to execute.
export function LessonStaticCodeBlock({ language, code, languageSwitcher }: LessonStaticCodeBlockProps) {
  async function copyCode() {
    await navigator.clipboard.writeText(code);
    toast.success("Code copied to clipboard.");
  }

  const copyButton = (
    <Button
      aria-label="Copy code"
      className="touch-target text-muted-foreground"
      size="icon"
      variant="ghost"
      onClick={copyCode}
    >
      <Copy aria-hidden className="h-3.5 w-3.5" />
    </Button>
  );

  if (!language) {
    return (
      <div className="relative overflow-hidden rounded-lg border border-border bg-card">
        <div className="absolute right-2 top-2">{copyButton}</div>
        <pre className="overflow-x-auto rounded-none bg-transparent p-4 pr-14 text-sm">
          <code>{code}</code>
        </pre>
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-lg border border-border bg-card">
      <div className="flex items-center gap-2 border-b border-border px-3 py-1.5">
        {languageSwitcher ?? <span className="text-xs font-semibold text-muted-foreground">{language}</span>}
        <div className="ml-auto">{copyButton}</div>
      </div>
      <pre className="overflow-x-auto rounded-none bg-transparent p-4 text-sm">
        <code>{code}</code>
      </pre>
    </div>
  );
}
