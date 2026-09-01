"use client";

import { useEffect, useRef } from "react";
import { tokenizeLine, type TokenClass } from "@/lib/algo-visualizer/highlight";
import type { LanguageId } from "@/lib/algo-visualizer/core/types";
import { cn } from "@/lib/utils";

interface CodeViewProps {
  code: string;
  currentLine: number | null;
  visitedLines: Set<number>;
  language: LanguageId;
}

const FILE_NAME: Record<LanguageId, string> = { python: "main.py", javascript: "main.js" };
const LANGUAGE_BADGE: Record<LanguageId, string> = { python: "PY", javascript: "JS" };

const TOKEN_CLASS: Record<TokenClass, string> = {
  keyword: "text-habit-violet",
  string: "text-habit-green",
  number: "text-habit-orange",
  comment: "italic text-muted-foreground",
  call: "text-habit-blue",
  plain: "text-foreground",
};

export function CodeView({ code, currentLine, visitedLines, language }: CodeViewProps) {
  const lines = code.split("\n");
  const activeRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    activeRef.current?.scrollIntoView({ block: "nearest" });
  }, [currentLine]);

  return (
    <div className="flex h-full flex-col overflow-hidden rounded-lg border border-border bg-card font-mono text-sm">
      <div className="flex shrink-0 items-center gap-2 border-b border-border bg-muted/40 px-3 py-2">
        <span aria-hidden className="h-2.5 w-2.5 rounded-full bg-destructive" />
        <span aria-hidden className="h-2.5 w-2.5 rounded-full bg-warning" />
        <span aria-hidden className="h-2.5 w-2.5 rounded-full bg-success" />
        <span className="ml-2 truncate text-xs text-muted-foreground">{FILE_NAME[language]}</span>
        <span className="ml-auto rounded-sm bg-primary/10 px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide text-primary">
          {LANGUAGE_BADGE[language]}
        </span>
      </div>
      <div className="flex-1 overflow-auto">
        {lines.map((line, i) => {
          const lineNo = i + 1;
          const isCurrent = lineNo === currentLine;
          const isVisited = !isCurrent && visitedLines.has(lineNo);
          const tokens = tokenizeLine(line, language);
          return (
            <div
              className={cn(
                "flex gap-3 whitespace-pre border-l-2 border-transparent px-3 py-0.5",
                isCurrent && "border-l-primary bg-primary/10",
                isVisited && "opacity-60",
              )}
              key={lineNo}
              ref={isCurrent ? activeRef : undefined}
            >
              <span className="w-8 shrink-0 select-none text-right text-muted-foreground/60">{lineNo}</span>
              <span>
                {line
                  ? tokens.map((tok, ti) => (
                      <span className={TOKEN_CLASS[tok.cls]} key={ti}>
                        {tok.text}
                      </span>
                    ))
                  : " "}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
