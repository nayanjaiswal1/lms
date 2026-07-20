"use client";

import { useState, useTransition } from "react";
import { CheckCircle2, Loader2, XCircle } from "lucide-react";
import { gradeQuery } from "@/lib/courses/sql-playground";
import { recordCheckAttemptAction } from "@/lib/courses/actions";
import { useModuleGate } from "@/components/courses/module-gate-provider";
import { CodeEditor } from "@/components/shared/code-editor";
import { Button } from "@/components/ui/button";
import type { KnowledgeCheckQuestion } from "@/lib/courses/markdown";

interface LessonSqlCheckQuestionProps {
  moduleId: string;
  question: KnowledgeCheckQuestion;
}

type Outcome = { kind: "idle" } | { kind: "correct" } | { kind: "incorrect"; reason?: string };

// The sql-typed sibling of LessonMcqQuestion inside an embedded knowledge
// check. Grading is client-side sql.js (gradeQuery, same as the standalone
// lesson-sql-challenge.tsx) — ponytail: there is no server-side SQL executor
// in this codebase (backend/internal/assessment/executor.go has no "sql"
// entry either), so this stays client-graded; add a server SQL sandbox if
// that trust level ever needs tightening. Unlike lesson-sql-challenge.tsx
// this does NOT complete the module itself — it records the attempt and
// marks the question passed in the shared gate, leaving ModuleCompleteButton
// to gate on all questions in the check being passed.
export function LessonSqlCheckQuestion({ moduleId, question }: LessonSqlCheckQuestionProps) {
  const [query, setQuery] = useState(question.starter ?? "");
  const [outcome, setOutcome] = useState<Outcome>({ kind: "idle" });
  const [isPending, startTransition] = useTransition();
  const { markPassed } = useModuleGate();
  const solved = outcome.kind === "correct";

  function submit() {
    startTransition(async () => {
      const graded = await gradeQuery(query, question.solution ?? "");
      await recordCheckAttemptAction({
        moduleID: moduleId,
        questionID: question.id,
        answer: { query },
        clientCorrect: graded.correct,
      });
      if (!graded.correct) {
        setOutcome({ kind: "incorrect", reason: graded.reason });
        return;
      }
      setOutcome({ kind: "correct" });
      markPassed(question.id);
    });
  }

  return (
    <div className="overflow-hidden rounded-lg border border-border bg-card">
      <div className="border-b border-border px-3 py-2">
        <p className="text-sm font-medium text-foreground">{question.prompt}</p>
      </div>

      <CodeEditor
        height={`${Math.min(Math.max(query.split("\n").length, 4), 20) * 1.5}rem`}
        language="sql"
        value={query}
        onChange={(value) => setQuery(value ?? "")}
      />

      <div className="flex items-center gap-2 border-t border-border px-3 py-1.5">
        <Button disabled={isPending || solved} size="sm" onClick={submit}>
          {solved ? (
            <>
              <CheckCircle2 aria-hidden className="mr-1 h-3.5 w-3.5" />
              Correct
            </>
          ) : isPending ? (
            <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />
          ) : (
            "Submit"
          )}
        </Button>
      </div>

      {outcome.kind === "incorrect" && (
        <div className="border-t border-border px-3 py-2">
          <p className="flex items-center gap-1.5 text-xs text-destructive">
            <XCircle aria-hidden className="h-3.5 w-3.5" />
            {outcome.reason ?? "Not quite — try again."}
          </p>
        </div>
      )}
    </div>
  );
}
