"use client";

import { useState } from "react";
import { Lock } from "lucide-react";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { LessonCodeRunner } from "@/components/courses/lesson-code-runner";
import { LessonStaticCodeBlock } from "@/components/courses/lesson-static-code-block";
import { RUNNABLE_LANGUAGES, isRunnableLanguage } from "@/lib/courses/runnable-languages";

interface LessonCodeBlockProps {
  language: string;
  code: string;
  /** Course-level kill switch (courses.disable_code_run) — Run never shows here, regardless of the selected language. */
  locked?: boolean;
}

// Learner-facing entry point for every lesson code segment: owns the
// language switcher shown in both the live-runner and static-block headers,
// and picks which of the two to render for the currently selected language.
// The switcher only ever relabels the same source text — it doesn't fetch or
// rewrite code — so picking a language Piston can execute (RUNNABLE_LANGUAGES)
// makes the block live (editor + Run), anything else makes it read-only.
// `locked` overrides this for courses where an instructor never wants
// students executing code at all (e.g. exploit snippets, fragments).
export function LessonCodeBlock({ language, code, locked = false }: LessonCodeBlockProps) {
  const original = language.trim().toLowerCase();
  const [selected, setSelected] = useState(original);

  // Untagged fences (bare ``` blocks) are usually terminal output, not code
  // in a specific language — leave those exactly as before: no switcher, no
  // header at all, just the block and a copy button.
  if (!original) {
    return <LessonStaticCodeBlock code={code} language={language} />;
  }

  const runnable = !locked && isRunnableLanguage(selected);

  // The block's authored language stays selectable even when it isn't one
  // Piston can run, so switching away and back never loses it.
  const options = original in RUNNABLE_LANGUAGES ? RUNNABLE_LANGUAGES : { ...RUNNABLE_LANGUAGES, [original]: language };

  const switcher = (
    <div className="flex items-center gap-1.5">
      <Select value={selected} onValueChange={setSelected}>
        <SelectTrigger
          aria-label="Code block language"
          className="h-6 w-auto gap-1 border-none bg-transparent px-1.5 text-xs font-semibold text-muted-foreground shadow-none hover:bg-muted"
        >
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {Object.entries(options).map(([value, label]) => (
            <SelectItem key={value} value={value}>{label}</SelectItem>
          ))}
        </SelectContent>
      </Select>
      {locked && (
        <Lock aria-label="Running code is disabled for this course" className="h-3 w-3 text-muted-foreground" />
      )}
    </div>
  );

  return runnable ? (
    <LessonCodeRunner initialCode={code} language={selected} languageSwitcher={switcher} />
  ) : (
    <LessonStaticCodeBlock code={code} language={language} languageSwitcher={switcher} />
  );
}
