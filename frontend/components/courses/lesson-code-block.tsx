"use client";

import { useState } from "react";
import { Lock } from "lucide-react";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { LessonCodeRunner } from "@/components/courses/lesson-code-runner";
import { LessonStaticCodeBlock } from "@/components/courses/lesson-static-code-block";
import type { CodeVariant } from "@/lib/courses/markdown";
import { RUNNABLE_LANGUAGES, isRunnableLanguage } from "@/lib/courses/runnable-languages";

interface LessonCodeBlockProps {
  variants: CodeVariant[];
  /** Course-level kill switch (courses.disable_code_run) — Run never shows here, regardless of the selected variant. */
  locked?: boolean;
}

// Learner-facing entry point for every lesson code segment: picks the live
// runner vs. a static display based on the currently selected variant's own
// language. A segment usually carries one variant, in which case the header
// is just a label; a segment authored with the `+` continuation marker
// (see markdownToSegments) carries the same snippet in 2-3 real languages,
// and the switcher picks between genuinely different source text — never a
// relabel of one string. Switching variants remounts the runner/static block
// (key={selectedIndex}) so each language gets its own fresh edit state.
export function LessonCodeBlock({ variants, locked = false }: LessonCodeBlockProps) {
  const [selectedIndex, setSelectedIndex] = useState(0);
  const variant = variants[selectedIndex] ?? variants[0];
  const original = variant.language.trim().toLowerCase();

  // Untagged fences (bare ``` blocks) are usually terminal output, not code
  // in a specific language — leave those exactly as before: no header at
  // all, just the block and a copy button. Multi-variant segments are always
  // language-tagged (the `+` marker requires a language), so this only ever
  // applies to a single-variant untagged block.
  if (!original && variants.length === 1) {
    return <LessonStaticCodeBlock code={variant.code} language={variant.language} />;
  }

  const runnable = !locked && isRunnableLanguage(original);

  const lockIcon = locked && (
    <Lock aria-label="Running code is disabled for this course" className="h-3 w-3 text-muted-foreground" />
  );

  const label =
    variants.length > 1 ? (
      <div className="flex items-center gap-1.5">
        <Select value={String(selectedIndex)} onValueChange={(v) => setSelectedIndex(Number(v))}>
          <SelectTrigger
            aria-label="Code block language"
            className="h-6 w-auto gap-1 border-none bg-transparent px-1.5 text-xs font-semibold text-muted-foreground shadow-none hover:bg-muted"
          >
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {variants.map((v, i) => (
              <SelectItem key={i} value={String(i)}>
                {RUNNABLE_LANGUAGES[v.language.trim().toLowerCase()] ?? v.language}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        {lockIcon}
      </div>
    ) : (
      <div className="flex items-center gap-1.5">
        <span className="text-xs font-semibold text-muted-foreground">
          {RUNNABLE_LANGUAGES[original] ?? variant.language}
        </span>
        {lockIcon}
      </div>
    );

  return runnable ? (
    <LessonCodeRunner initialCode={variant.code} key={selectedIndex} language={original} languageSwitcher={label} />
  ) : (
    <LessonStaticCodeBlock code={variant.code} key={selectedIndex} language={variant.language} languageSwitcher={label} />
  );
}
