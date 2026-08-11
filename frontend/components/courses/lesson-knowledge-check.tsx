import { HelpCircle } from "lucide-react";
import type { KnowledgeCheckQuestion } from "@/lib/courses/markdown";
import { LessonMcqQuestion } from "@/components/courses/lesson-mcq-question";
import { LessonSqlCheckQuestion } from "@/components/courses/lesson-sql-check-question";

interface LessonKnowledgeCheckProps {
  moduleId: string;
  questions: KnowledgeCheckQuestion[];
}

// Layout-only — owns no state of its own. Each question tracks its own
// submit/outcome locally and reports a pass up through useModuleGate(),
// which ModuleCompleteButton reads to decide whether Mark Complete unlocks.
export function LessonKnowledgeCheck({ moduleId, questions }: LessonKnowledgeCheckProps) {
  return (
    <div className="card-raised flex flex-col gap-4 border-primary/30">
      <div>
        <div className="flex items-center gap-2">
          <HelpCircle aria-hidden className="h-5 w-5 text-primary" />
          <span className="text-base font-semibold text-foreground">Knowledge Check</span>
        </div>
        <p className="mt-1 text-sm text-muted-foreground">
          Answer all {questions.length} questions correctly to unlock Mark as Complete.
        </p>
      </div>
      {questions.map((question) =>
        question.type === "sql" ? (
          <LessonSqlCheckQuestion key={question.id} moduleId={moduleId} question={question} />
        ) : (
          <LessonMcqQuestion key={question.id} moduleId={moduleId} question={question} />
        ),
      )}
    </div>
  );
}
