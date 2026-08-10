import { Fragment } from "react";
import type { Segment } from "@/lib/courses/markdown";
import { isLabSessionActive, type GetSessionResponse, type Lab } from "@/lib/labs";
import type { Highlight } from "@/lib/server/highlights";
import { markHighlightsInHtml } from "@/lib/highlights/mark-html";
import { LessonCodeRunner } from "@/components/courses/lesson-code-runner";
import { LessonSqlRunner } from "@/components/courses/lesson-sql-runner";
import { LessonSqlChallenge } from "@/components/courses/lesson-sql-challenge";
import { LessonKnowledgeCheck } from "@/components/courses/lesson-knowledge-check";
import { LessonReflection } from "@/components/courses/lesson-reflection";
import { LessonFigure } from "@/components/courses/lesson-figure";
import { LessonHtml } from "@/components/courses/lesson-html";
import { isRunnableLanguage } from "@/lib/courses/runnable-languages";
import { LessonLabHero } from "@/components/courses/lesson-lab-hero";
import { LessonLabTaskCard } from "@/components/courses/lesson-lab-task-card";
import { LessonLabWorkspacePane } from "@/components/courses/lesson-lab-workspace-pane";

interface ModuleNotesProps {
  moduleId: string;
  segments: Segment[];
  initialReflection: string | null;
  lab?: Lab | null;
  initialSession?: GetSessionResponse | null;
  highlights?: Highlight[];
}

export function ModuleNotes({
  moduleId,
  segments,
  initialReflection,
  lab = null,
  initialSession = null,
  highlights = [],
}: ModuleNotesProps) {
  const firstLabTaskIndex = segments.findIndex((s) => s.type === "lab-task");
  // True once the linked lab is actually running — ModuleNotes then puts the
  // notes and the live workspace side by side instead of stacking the
  // workspace inline where the [[lab-task:N]] marker happens to fall.
  const isLabOpen = Boolean(lab && initialSession && isLabSessionActive(initialSession.session.status));
  // While the lab is not-started OR provisioning, page.tsx's rail owns the
  // hero (badges, title, Launch button / provisioning status) — see
  // showLabInRail there. This copy only takes over once isLabOpen, so
  // there's exactly one <LessonLabHero> on screen at a time: the rail
  // during not-started/provisioning (it disappears once isLabOpen, hidden by
  // the wide no-rail layout switch), this inline copy once running/paused.

  const body = (
    <div className="card-base flex flex-col gap-4 p-6">
      {segments.map((segment, index) => {
        switch (segment.type) {
          case "html":
            return (
              <LessonHtml
                html={markHighlightsInHtml(segment.html, highlights, index)}
                key={index}
                segmentIndex={index}
              />
            );
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
                {index === firstLabTaskIndex && isLabOpen && <LessonLabHero />}
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
      {isLabOpen ? (
        <div className="grid items-start gap-6 lg:grid-cols-2">
          {body}
          <LessonLabWorkspacePane />
        </div>
      ) : (
        body
      )}
    </article>
  );
}
