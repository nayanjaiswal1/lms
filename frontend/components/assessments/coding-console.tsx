import { CheckCircle2, Loader2, XCircle } from "lucide-react";
import { cn } from "@/lib/utils";
import type { RunResult } from "@/lib/assessments/types";

interface SampleCase {
  stdin: string;
  expected: string;
}

interface CodingConsoleProps {
  sampleCases: SampleCase[];
  tab: "testcase" | "result";
  running: boolean;
  result: RunResult | null;
  error: string | null;
  onTabChange: (tab: "testcase" | "result") => void;
}

function OutputBox({ label, text }: { label: string; text: string }) {
  return (
    <div className="rounded-[--radius-md] bg-muted p-3">
      <p className="mb-1 text-xs text-muted-foreground">{label}</p>
      <pre className="overflow-x-auto whitespace-pre-wrap font-mono text-xs text-foreground">{text}</pre>
    </div>
  );
}

// Result cases come back in the same order the (non-hidden) sample cases were
// sent to the executor, so zipping by index against `sampleCases` is safe —
// both are derived from the same server-side test-case list filtered to
// non-hidden entries in the same relative order.
export function CodingConsole({ sampleCases, tab, running, result, error, onTabChange }: CodingConsoleProps) {
  return (
    <div className="flex h-full flex-col border-t border-border">
      <div className="flex items-center gap-1 border-b border-border bg-muted/30 px-3 py-1.5">
        <button
          className={cn(
            "rounded px-2.5 py-1 text-xs font-medium transition-colors",
            tab === "testcase" ? "bg-background text-foreground shadow-sm" : "text-muted-foreground hover:text-foreground",
          )}
          type="button"
          onClick={() => onTabChange("testcase")}
        >
          Testcase
        </button>
        <button
          className={cn(
            "flex items-center gap-1.5 rounded px-2.5 py-1 text-xs font-medium transition-colors",
            tab === "result" ? "bg-background text-foreground shadow-sm" : "text-muted-foreground hover:text-foreground",
          )}
          type="button"
          onClick={() => onTabChange("result")}
        >
          Result
          {result && (
            result.status === "passed" ? (
              <CheckCircle2 aria-hidden className="h-3 w-3 text-ai" />
            ) : (
              <XCircle aria-hidden className="h-3 w-3 text-destructive" />
            )
          )}
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-3">
        {tab === "testcase" ? (
          <div className="flex flex-col gap-3">
            {sampleCases.map((c, i) => (
              <div className="flex flex-col gap-2" key={i}>
                <p className="text-xs font-medium text-muted-foreground">Case {i + 1}</p>
                <OutputBox label="Input" text={c.stdin} />
                <OutputBox label="Expected" text={c.expected} />
              </div>
            ))}
          </div>
        ) : running ? (
          <div className="flex h-full flex-col items-center justify-center gap-2 text-muted-foreground">
            <Loader2 aria-hidden className="h-5 w-5 animate-spin" />
            <p className="text-xs">Running your code against sample tests…</p>
          </div>
        ) : error ? (
          <div className="flex items-start gap-2 rounded-[--radius-md] bg-destructive/10 p-3 text-sm text-destructive">
            <XCircle aria-hidden className="mt-0.5 h-4 w-4 shrink-0" />
            {error}
          </div>
        ) : result ? (
          <div className="flex flex-col gap-4">
            <div className="flex flex-wrap items-center gap-3">
              <span
                className={cn(
                  "flex items-center gap-1.5 text-sm font-semibold",
                  result.status === "passed" ? "text-ai" : "text-destructive",
                )}
              >
                {result.status === "passed" ? (
                  <CheckCircle2 aria-hidden className="h-4 w-4" />
                ) : (
                  <XCircle aria-hidden className="h-4 w-4" />
                )}
                {result.status === "passed"
                  ? "Accepted"
                  : result.status === "error"
                    ? "Compile / Runtime Error"
                    : "Wrong Answer"}
              </span>
              <span className="text-xs text-muted-foreground tabular-nums">
                {result.tests_passed}/{result.tests_total} test cases passed
              </span>
              {result.runtime_ms > 0 && (
                <span className="text-xs text-muted-foreground tabular-nums">{result.runtime_ms} ms</span>
              )}
            </div>

            {result.compile_output && <OutputBox label="Compile output" text={result.compile_output} />}

            {result.cases.map((c, i) => (
              <div className="flex flex-col gap-2" key={c.case_id || i}>
                <p
                  className={cn(
                    "text-xs font-medium",
                    c.passed ? "text-ai" : "text-destructive",
                  )}
                >
                  Case {i + 1} — {c.passed ? "Passed" : c.status.replace("_", " ")}
                </p>
                {sampleCases[i] && <OutputBox label="Input" text={sampleCases[i].stdin} />}
                {sampleCases[i] && <OutputBox label="Expected" text={sampleCases[i].expected} />}
                {c.stdout !== undefined && <OutputBox label="Your output" text={c.stdout} />}
                {c.stderr && <OutputBox label="Stderr" text={c.stderr} />}
              </div>
            ))}
          </div>
        ) : (
          <div className="flex h-full items-center justify-center text-xs text-muted-foreground">
            Run your code to see results against the sample test cases.
          </div>
        )}
      </div>
    </div>
  );
}
