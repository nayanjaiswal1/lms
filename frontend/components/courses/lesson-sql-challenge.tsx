"use client";

import { useRef, useState, useTransition } from "react";
import { CheckCircle2, Loader2, Play, XCircle } from "lucide-react";
import type { Database, SqlValue } from "sql.js";
import { createSeededDatabase, gradeQuery } from "@/lib/courses/sql-playground";
import { updateProgressAction } from "@/lib/courses/actions";
import { showRewardToasts } from "@/components/shared/reward-toast";
import { CodeEditor } from "@/components/shared/code-editor";
import { Button } from "@/components/ui/button";

interface LessonSqlChallengeProps {
  moduleId: string;
  prompt: string;
  starter: string;
  solution: string;
}

type Outcome =
  | { kind: "idle" }
  | { kind: "rows"; columns: string[]; values: SqlValue[][] }
  | { kind: "affected"; count: number }
  | { kind: "error"; message: string }
  | { kind: "correct" }
  | { kind: "incorrect"; reason?: string };

function formatCell(value: SqlValue): string {
  if (value === null) return "NULL";
  if (value instanceof Uint8Array) return "[blob]";
  return String(value);
}

// A graded practice exercise embedded directly in a lesson — write a query,
// Run it to preview the result (ungraded), Submit to check it against the
// lesson author's solution query. A correct submission calls the same
// progress action ModuleCompleteButton uses, so solving it marks the lesson
// module complete and awards the same XP/reward toast.
export function LessonSqlChallenge({ moduleId, prompt, starter, solution }: LessonSqlChallengeProps) {
  const [query, setQuery] = useState(starter);
  const [outcome, setOutcome] = useState<Outcome>({ kind: "idle" });
  const [isPending, startTransition] = useTransition();
  const dbRef = useRef<Database | null>(null);
  const solved = outcome.kind === "correct";

  function run() {
    startTransition(async () => {
      try {
        if (!dbRef.current) dbRef.current = await createSeededDatabase();
        const results = dbRef.current.exec(query);
        if (results.length > 0) {
          const last = results[results.length - 1];
          setOutcome({ kind: "rows", columns: last.columns, values: last.values });
        } else {
          setOutcome({ kind: "affected", count: dbRef.current.getRowsModified() });
        }
      } catch (err) {
        setOutcome({ kind: "error", message: err instanceof Error ? err.message : String(err) });
      }
    });
  }

  function submit() {
    startTransition(async () => {
      const result = await gradeQuery(query, solution);
      if (!result.correct) {
        setOutcome({ kind: "incorrect", reason: result.reason });
        return;
      }
      setOutcome({ kind: "correct" });
      const progress = await updateProgressAction({ moduleID: moduleId, status: "completed" });
      if (progress.ok && progress.data?.rewards) showRewardToasts(progress.data.rewards);
    });
  }

  return (
    <div className="overflow-hidden rounded-lg border border-primary/40 bg-card">
      <div className="border-b border-border px-3 py-2">
        <span className="text-xs font-semibold text-primary">Practice Exercise</span>
        <p className="mt-1 text-sm text-foreground">{prompt}</p>
      </div>

      <CodeEditor
        height={`${Math.min(Math.max(query.split("\n").length, 4), 20) * 1.5}rem`}
        language="sql"
        value={query}
        onChange={(value) => setQuery(value ?? "")}
      />

      <div className="flex items-center gap-2 border-t border-border px-3 py-1.5">
        <Button disabled={isPending} size="sm" variant="secondary" onClick={run}>
          {isPending ? <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" /> : <Play aria-hidden className="h-3.5 w-3.5" />}
          Run
        </Button>
        <Button disabled={isPending || solved} size="sm" onClick={submit}>
          {solved ? (
            <>
              <CheckCircle2 aria-hidden className="mr-1 h-3.5 w-3.5" />
              Solved
            </>
          ) : (
            "Submit"
          )}
        </Button>
      </div>

      {outcome.kind === "correct" && (
        <div className="border-t border-border px-3 py-2">
          <p className="flex items-center gap-1.5 text-xs text-success">
            <CheckCircle2 aria-hidden className="h-3.5 w-3.5" />
            Correct — module marked complete.
          </p>
        </div>
      )}

      {outcome.kind === "incorrect" && (
        <div className="border-t border-border px-3 py-2">
          <p className="flex items-center gap-1.5 text-xs text-destructive">
            <XCircle aria-hidden className="h-3.5 w-3.5" />
            {outcome.reason ?? "Not quite — try again."}
          </p>
        </div>
      )}

      {outcome.kind === "error" && (
        <div className="border-t border-border px-3 py-2">
          <p className="text-xs text-destructive">{outcome.message}</p>
        </div>
      )}

      {outcome.kind === "affected" && (
        <div className="border-t border-border px-3 py-2">
          <p className="text-xs text-muted-foreground">
            Query OK — {outcome.count} row{outcome.count === 1 ? "" : "s"} affected.
          </p>
        </div>
      )}

      {outcome.kind === "rows" &&
        (outcome.values.length === 0 ? (
          <div className="border-t border-border px-3 py-2">
            <p className="text-xs text-muted-foreground">Query returned 0 rows.</p>
          </div>
        ) : (
          <div className="table-responsive max-h-64 border-t border-border px-3 py-2">
            <table className="w-full text-xs">
              <thead>
                <tr className="border-b border-border text-left text-muted-foreground">
                  {outcome.columns.map((col) => (
                    <th className="px-2 py-1 font-medium" key={col}>
                      {col}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {outcome.values.map((row, rowIndex) => (
                  <tr className="border-b border-border/50" key={rowIndex}>
                    {row.map((cell, cellIndex) => (
                      <td className="px-2 py-1 font-mono text-foreground" key={cellIndex}>
                        {formatCell(cell)}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ))}
    </div>
  );
}
