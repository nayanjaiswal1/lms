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
    <div className="flex flex-col gap-4 rounded-lg border border-primary/40 bg-card p-4">
      <div>
        <span className="text-xs font-semibold text-primary">Knowledge Check</span>
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
