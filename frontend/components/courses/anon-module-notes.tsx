import { Lock, Boxes } from "lucide-react";
import type { Segment } from "@/lib/courses/markdown";
import { LessonHtml } from "@/components/courses/lesson-html";
import { LessonFigure } from "@/components/courses/lesson-figure";
import { LessonStaticCodeBlock } from "@/components/courses/lesson-static-code-block";
import { LessonSqlRunner } from "@/components/courses/lesson-sql-runner";
import { AnonLessonReflection } from "@/components/courses/anon-lesson-reflection";

interface AnonModuleNotesProps {
  courseId: string;
  moduleId: string;
  segments: Segment[];
  initialReflection: string | null;
  isSystemDesign?: boolean;
}

// Placeholder for segment types that need a real account to be meaningful —
// grading a knowledge check, tracking a SQL-challenge attempt, or opening a
// lab task all write server-side progress an anonymous visitor doesn't have.
function SignInToTry({ what }: { what: string }) {
  return (
    <div className="flex items-center gap-2 rounded-lg border border-dashed border-border bg-muted/40 px-4 py-3 text-sm text-muted-foreground">
      <Lock aria-hidden className="h-4 w-4 shrink-0" />
      Sign in to try {what}.
    </div>
  );
}

// Read-only anonymous counterpart to module-notes.tsx (docs/anonymous.md):
// same segment rendering, but interactive segments that need a real account
// (knowledge checks, SQL challenges, lab tasks) become a sign-in prompt
// instead, and code blocks never get the live in-page runner. Reflect is the
// one interactive piece anonymous visitors keep, saved to localStorage via
// AnonLessonReflection.
export function AnonModuleNotes({ courseId, moduleId, segments, initialReflection, isSystemDesign }: AnonModuleNotesProps) {
  return (
    <article className="flex flex-col gap-4">
      <div className="flex flex-col gap-8">
        {isSystemDesign && (
          <div className="flex items-center gap-2 rounded-lg border border-dashed border-border bg-muted/40 px-4 py-3 text-sm text-muted-foreground">
            <Boxes aria-hidden className="h-4 w-4 shrink-0" />
            Sign in to open the interactive design canvas for this exercise.
          </div>
        )}
        {segments.map((segment, index) => {
          switch (segment.type) {
            case "html":
              return <LessonHtml html={segment.html} key={index} segmentIndex={index} />;
            case "code":
              return <LessonStaticCodeBlock code={segment.code} key={index} language={segment.language} />;
            case "sql-try":
              return <LessonSqlRunner initialQuery={segment.query} key={index} />;
            case "sql-challenge":
              return <SignInToTry key={index} what="this SQL challenge" />;
            case "knowledge-check":
              return <SignInToTry key={index} what="this knowledge check" />;
            case "image":
              return (
                <LessonFigure
                  alt={segment.alt}
                  caption={segment.caption}
                  key={index}
                  src={segment.src}
                />
              );
            case "lab-task":
              return <SignInToTry key={index} what="this lab task" />;
          }
        })}
        <AnonLessonReflection courseId={courseId} initialResponse={initialReflection} moduleId={moduleId} />
      </div>
    </article>
  );
}
