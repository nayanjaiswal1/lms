"use client";

import { EyeOff, HelpCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { setHideKnowledgeChecks, useHideKnowledgeChecks } from "@/lib/courses/knowledge-check-settings";
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
  const hidden = useHideKnowledgeChecks();
  if (hidden) return null;
  return (
    <div className="card-raised flex flex-col gap-4 border-primary/30">
      <div>
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <HelpCircle aria-hidden className="h-5 w-5 text-primary" />
            <span className="text-base font-semibold text-foreground">Knowledge Check</span>
          </div>
          <Button size="sm" type="button" variant="ghost" onClick={() => setHideKnowledgeChecks(true)}>
            <EyeOff aria-hidden className="mr-2 h-4 w-4" />
            Hide in all courses
          </Button>
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
