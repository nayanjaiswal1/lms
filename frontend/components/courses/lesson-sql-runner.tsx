"use client";

import { useRef, useState, useTransition } from "react";
import { Loader2, Play, RotateCcw } from "lucide-react";
import type { Database, SqlValue } from "sql.js";
import { createSeededDatabase } from "@/lib/courses/sql-playground";
import { CodeEditor } from "@/components/shared/code-editor";
import { Button } from "@/components/ui/button";

interface LessonSqlRunnerProps {
  initialQuery: string;
}

type Outcome =
  | { kind: "idle" }
  | { kind: "rows"; columns: string[]; values: SqlValue[][] }
  | { kind: "affected"; count: number }
  | { kind: "error"; message: string };

function formatCell(value: SqlValue): string {
  if (value === null) return "NULL";
  if (value instanceof Uint8Array) return "[blob]";
  return String(value);
}

// Runs entirely client-side against an in-browser SQLite engine (sql.js) —
// the w3schools-style "Try it Yourself" box for the SQL Mastery course. No
// backend round-trip, no container: each instance owns its own isolated,
// seeded database so edits in one box never affect another on the page.
export function LessonSqlRunner({ initialQuery }: LessonSqlRunnerProps) {
  const [query, setQuery] = useState(initialQuery);
  const [outcome, setOutcome] = useState<Outcome>({ kind: "idle" });
  const [isRunning, startRun] = useTransition();
  const dbRef = useRef<Database | null>(null);

  const isDirty = query !== initialQuery || outcome.kind !== "idle";

  function run() {
    startRun(async () => {
      try {
        if (!dbRef.current) {
          dbRef.current = await createSeededDatabase();
        }
        const db = dbRef.current;
        const results = db.exec(query);
        if (results.length > 0) {
          const last = results[results.length - 1];
          setOutcome({ kind: "rows", columns: last.columns, values: last.values });
        } else {
          setOutcome({ kind: "affected", count: db.getRowsModified() });
        }
      } catch (err) {
        setOutcome({ kind: "error", message: err instanceof Error ? err.message : String(err) });
      }
    });
  }

  function reset() {
    dbRef.current?.close();
    dbRef.current = null;
    setQuery(initialQuery);
    setOutcome({ kind: "idle" });
  }

  return (
    <div className="overflow-hidden rounded-lg border border-border bg-card">
      <div className="flex items-center gap-2 border-b border-border px-3 py-1.5">
        <span className="text-xs font-semibold text-muted-foreground">SQL — Try it Yourself</span>
        <div className="ml-auto flex items-center gap-1">
          {isDirty && (
            <Button
              aria-label="Reset query and database"
              className="touch-target text-muted-foreground"
              size="icon"
              variant="ghost"
              onClick={reset}
            >
              <RotateCcw aria-hidden className="h-3.5 w-3.5" />
            </Button>
          )}
          <Button disabled={isRunning} size="sm" variant="secondary" onClick={run}>
            {isRunning ? (
              <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />
            ) : (
              <Play aria-hidden className="h-3.5 w-3.5" />
            )}
            Run SQL
          </Button>
        </div>
      </div>

      <CodeEditor
        height={`${Math.min(Math.max(query.split("\n").length, 4), 20) * 1.5}rem`}
        language="sql"
        value={query}
        onChange={(value) => setQuery(value ?? "")}
      />

      {outcome.kind !== "idle" && (
        <div className="border-t border-border px-3 py-2">
          {outcome.kind === "error" && <p className="text-xs text-destructive">{outcome.message}</p>}
          {outcome.kind === "affected" && (
            <p className="text-xs text-muted-foreground">
              Query OK — {outcome.count} row{outcome.count === 1 ? "" : "s"} affected.
            </p>
          )}
          {outcome.kind === "rows" &&
            (outcome.values.length === 0 ? (
              <p className="text-xs text-muted-foreground">Query returned 0 rows.</p>
            ) : (
              <div className="table-responsive max-h-64">
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
      )}
    </div>
  );
}
