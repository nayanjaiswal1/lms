import type { Segment } from "@/lib/courses/markdown";
import { LessonHtml } from "@/components/courses/lesson-html";
import { LessonFigure } from "@/components/courses/lesson-figure";

interface DesignGuidancePanelProps {
  segments: Segment[];
}

// The "How to answer" tab — reuses the same markdown segment rendering as
// ModuleNotes (html/code/image), minus lab-task handling which doesn't apply
// to system_design modules. The guidance content itself is the module's
// existing content_body (e.g. "Why interviewers ask this" / "Requirements")
// — no separate question-bank authoring needed.
export function DesignGuidancePanel({ segments }: DesignGuidancePanelProps) {
  return (
    <div className="flex flex-col gap-4 text-sm">
      {segments.map((segment, index) => {
        switch (segment.type) {
          case "html":
            return <LessonHtml html={segment.html} key={index} />;
          case "code":
            return (
              <pre className="overflow-x-auto rounded-lg bg-muted p-4 text-xs" key={index}>
                <code>{segment.code}</code>
              </pre>
            );
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
            return null;
        }
      })}
    </div>
  );
}
