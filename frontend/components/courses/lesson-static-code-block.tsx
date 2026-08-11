"use client";

import { Copy } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";

interface LessonStaticCodeBlockProps {
  language: string;
  code: string;
}

// Chrome-matched sibling of LessonCodeRunner for languages that aren't
// runnable in-page (see isRunnableLanguage) — same header bar and copy
// button, no editor/run affordances since there's nothing to execute.
export function LessonStaticCodeBlock({ language, code }: LessonStaticCodeBlockProps) {
  async function copyCode() {
    await navigator.clipboard.writeText(code);
    toast.success("Code copied to clipboard.");
  }

  return (
    <div className="overflow-hidden rounded-lg border border-border bg-card">
      <div className="flex items-center gap-2 border-b border-border px-3 py-1.5">
        <span className="text-xs font-semibold text-muted-foreground">{language}</span>
        <Button
          aria-label="Copy code"
          className="touch-target ml-auto text-muted-foreground"
          size="icon"
          variant="ghost"
          onClick={copyCode}
        >
          <Copy aria-hidden className="h-3.5 w-3.5" />
        </Button>
      </div>
      <pre className="overflow-x-auto p-4 text-sm">
        <code>{code}</code>
      </pre>
    </div>
  );
}
