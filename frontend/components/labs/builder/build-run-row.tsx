import { CheckCircle2, XCircle } from "lucide-react";
import type { RunReport } from "@/lib/labs/builder/types";

interface BuildRunRowProps {
  run: RunReport;
}

/** One verification run: expectations, failures and the grader's stderr tail. */
export function BuildRunRow({ run }: BuildRunRowProps) {
  const failed = !run.passed;
  return (
    <li className="border-b border-border py-3 last:border-0">
      <details>
        <summary className="flex cursor-pointer items-start gap-2 text-sm">
          {failed ? (
            <XCircle aria-label="Failed" className="mt-0.5 h-4 w-4 shrink-0 text-destructive" />
          ) : (
            <CheckCircle2 aria-label="Passed" className="mt-0.5 h-4 w-4 shrink-0 text-success" />
          )}
          <span className="min-w-0">
            <span className="font-mono">{run.name}</span>
            <span className="block text-xs text-muted-foreground">{run.description}</span>
          </span>
        </summary>
        <div className="mt-2 flex flex-col gap-2 pl-6 text-xs">
          {run.error && <p className="text-destructive">{run.error}</p>}
          {(run.failures ?? []).map((f) => (
            <p className="text-destructive" key={f}>{f}</p>
          ))}
          {(run.expectations ?? []).length > 0 && (
            <p className="text-muted-foreground">Expected: {(run.expectations ?? []).join("; ")}</p>
          )}
          {(run.author_messages ?? []).length > 0 && (
            <p className="text-muted-foreground">Grader messages: {(run.author_messages ?? []).join(" | ")}</p>
          )}
          <p className="text-muted-foreground">Sandbox setup {run.setup_seconds.toFixed(1)}s</p>
          {run.stderr_tail && (
            <pre className="table-responsive max-h-64 rounded-md bg-muted p-3 font-mono text-xs">{run.stderr_tail}</pre>
          )}
        </div>
      </details>
    </li>
  );
}
