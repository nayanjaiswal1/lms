"use client"

import { CheckCircle2, XCircle, AlertCircle } from "lucide-react"
import type { LabRunResult, LabSubmitResult, LabTask } from "@/lib/labs"

interface SandboxTestsPanelProps {
  tasks: LabTask[]
  runResult: LabRunResult | null
  submitResult: LabSubmitResult | null
  error: string | null
}

/**
 * Content of the sandbox bottom panel's Tests tab: raw sample-test output
 * from Run, and per-task pass/fail from Submit. Purely presentational.
 */
export function SandboxTestsPanel({ tasks, runResult, submitResult, error }: SandboxTestsPanelProps) {
  const titleFor = (taskId: string) =>
    tasks.find((t) => t.task_id === taskId)?.title ?? taskId

  if (!runResult && !submitResult && !error) {
    return (
      <div className="empty-state h-full">
        <p className="text-sm text-muted-foreground">
          Run your sample tests or submit for grading — results appear here.
        </p>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      {error && (
        <div className="flex items-center gap-2 rounded-md border border-destructive/30 bg-destructive/10 px-3 py-2" role="alert">
          <AlertCircle aria-hidden className="h-4 w-4 text-destructive shrink-0" />
          <p className="text-sm text-destructive">{error}</p>
        </div>
      )}

      {submitResult && (
        <section aria-label="Submission results" className="flex flex-col gap-2">
          <div className="flex items-center gap-2">
            <h4 className="text-sm font-semibold">Submission</h4>
            <span className="text-xs text-muted-foreground">
              Score: {submitResult.score}
            </span>
            {submitResult.session_completed && (
              <span className="flex items-center gap-1 text-xs font-medium text-success">
                <CheckCircle2 aria-hidden className="h-3.5 w-3.5" />
                Completed
              </span>
            )}
          </div>
          <ul className="flex flex-col gap-1">
            {submitResult.results.map((r) => (
              <li className="flex items-start gap-2 text-sm" key={r.task_id}>
                {r.passed ? (
                  <CheckCircle2 aria-hidden className="h-4 w-4 text-success shrink-0 mt-0.5" />
                ) : (
                  <XCircle aria-hidden className="h-4 w-4 text-destructive shrink-0 mt-0.5" />
                )}
                <div className="min-w-0 flex flex-col gap-0.5">
                  <span className={r.passed ? "text-foreground" : "text-destructive"}>
                    {titleFor(r.task_id)}
                  </span>
                  {!r.passed && (r.stdout || r.stderr) && (
                    <pre className="text-xs text-muted-foreground font-mono whitespace-pre-wrap break-words">
                      {[r.stdout, r.stderr].filter(Boolean).join("\n")}
                    </pre>
                  )}
                </div>
              </li>
            ))}
          </ul>
        </section>
      )}

      {runResult && (
        <section aria-label="Run output" className="flex flex-col gap-2">
          <div className="flex items-center gap-2">
            <h4 className="text-sm font-semibold">Run output</h4>
            <span
              className={
                runResult.exit_code === 0
                  ? "text-xs font-medium text-success"
                  : "text-xs font-medium text-destructive"
              }
            >
              exit {runResult.exit_code}
            </span>
          </div>
          {(runResult.stdout || runResult.stderr) ? (
            <pre className="rounded-md bg-muted p-3 text-xs font-mono whitespace-pre-wrap break-words overflow-x-auto">
              {runResult.stdout}
              {runResult.stderr && (
                <span className="text-destructive">{runResult.stderr}</span>
              )}
            </pre>
          ) : (
            <p className="text-xs text-muted-foreground">No output.</p>
          )}
        </section>
      )}
    </div>
  )
}
