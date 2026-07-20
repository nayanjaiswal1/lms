import { Fragment } from "react";
import type { Segment } from "@/lib/courses/markdown";
import type { GetSessionResponse, Lab } from "@/lib/labs";
import { LessonCodeRunner } from "@/components/courses/lesson-code-runner";
import { LessonSqlRunner } from "@/components/courses/lesson-sql-runner";
import { LessonSqlChallenge } from "@/components/courses/lesson-sql-challenge";
import { LessonKnowledgeCheck } from "@/components/courses/lesson-knowledge-check";
import { LessonReflection } from "@/components/courses/lesson-reflection";
import { LessonFigure } from "@/components/courses/lesson-figure";
import { LessonHtml } from "@/components/courses/lesson-html";
import { ModuleCompleteButton } from "@/components/courses/module-complete-button";
import { isRunnableLanguage } from "@/lib/courses/runnable-languages";
import { LessonLabProvider } from "@/components/courses/lesson-lab-provider";
import { LessonLabHero } from "@/components/courses/lesson-lab-hero";
import { LessonLabTaskCard } from "@/components/courses/lesson-lab-task-card";

interface ModuleNotesProps {
  moduleId: string;
  title: string;
  segments: Segment[];
  initialCompleted: boolean;
  initialReflection: string | null;
  lab?: Lab | null;
  initialSession?: GetSessionResponse | null;
}

export function ModuleNotes({
  moduleId,
  title,
  segments,
  initialCompleted,
  initialReflection,
  lab = null,
  initialSession = null,
}: ModuleNotesProps) {
  const firstLabTaskIndex = segments.findIndex((s) => s.type === "lab-task");

  const body = (
    <div className="card-base flex flex-col gap-4 p-6">
      {segments.map((segment, index) => {
        switch (segment.type) {
          case "html":
            return <LessonHtml html={segment.html} key={index} />;
          case "code":
            // Runnable languages get the in-page code runner (feature 2);
            // anything else stays a static block.
            return isRunnableLanguage(segment.language) ? (
              <LessonCodeRunner
                initialCode={segment.code}
                key={index}
                language={segment.language}
              />
            ) : (
              <pre className="overflow-x-auto rounded-lg bg-muted p-4 text-sm" key={index}>
                <code>{segment.code}</code>
              </pre>
            );
          case "sql-try":
            return <LessonSqlRunner initialQuery={segment.query} key={index} />;
          case "sql-challenge":
            return (
              <LessonSqlChallenge
                key={index}
                moduleId={moduleId}
                prompt={segment.prompt}
                solution={segment.solution}
                starter={segment.starter}
              />
            );
          case "knowledge-check":
            return <LessonKnowledgeCheck key={index} moduleId={moduleId} questions={segment.questions} />;
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
            if (!lab) return null;
            return (
              <Fragment key={index}>
                {index === firstLabTaskIndex && <LessonLabHero />}
                <LessonLabTaskCard position={segment.position} />
              </Fragment>
            );
        }
      })}
      <LessonReflection initialResponse={initialReflection} moduleId={moduleId} />
    </div>
  );

  return (
    <article className="flex flex-col gap-4">
      {/* Visually hidden: the module title is already shown in the course
          sidebar rail (desktop) and the mobile drawer subheader, so showing
          it a third time here was pure duplication. Kept for screen readers
          and document outline. */}
      <h2 className="sr-only">{title}</h2>
      <div className="flex justify-end">
        {/* At xl+ this button moves into the ModuleProgressRail instead. */}
        <ModuleCompleteButton className="xl:hidden" initialCompleted={initialCompleted} moduleId={moduleId} />
      </div>
      {lab ? (
        <LessonLabProvider initialSession={initialSession} lab={lab}>
          {body}
        </LessonLabProvider>
      ) : (
        body
      )}
    </article>
  );
}
