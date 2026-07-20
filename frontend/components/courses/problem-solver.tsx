"use client";

import { useState } from "react";
import { LessonCodeRunner } from "@/components/courses/lesson-code-runner";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { RUNNABLE_LANGUAGES } from "@/lib/courses/runnable-languages";

const LANGUAGE_OPTIONS = Object.entries(RUNNABLE_LANGUAGES)
  .filter(([value]) => value !== "python3")
  .map(([value, label]) => ({ value, label }));

const COMMENT_PREFIX: Record<string, string> = {
  python: "#",
  javascript: "//",
  typescript: "//",
  go: "//",
};

function starterCode(language: string, title: string, url: string): string {
  const c = COMMENT_PREFIX[language] ?? "//";
  const header = `${c} ${title}\n${c} ${url}\n\n`;
  if (language === "go") {
    return `${header}package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println()\n}\n`;
  }
  return header;
}

interface ProblemSolverProps {
  title: string;
  url: string;
}

// LeetCode-style solve pane: language picker + tall editor + Run. Runs go
// through the same session-less snippet endpoint as lesson code blocks —
// no scoring, just stdout/stderr; the problem statement stays on LeetCode.
export function ProblemSolver({ title, url }: ProblemSolverProps) {
  const [language, setLanguage] = useState("python");

  return (
    <div className="flex flex-col gap-3">
      <Select value={language} onValueChange={setLanguage}>
        <SelectTrigger aria-label="Language" className="touch-target w-full sm:w-44">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {LANGUAGE_OPTIONS.map((option) => (
            <SelectItem key={option.value} value={option.value}>
              {option.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      <LessonCodeRunner
        initialCode={starterCode(language, title, url)}
        key={language}
        language={language}
        minLines={20}
      />
    </div>
  );
}
