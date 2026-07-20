"use client";

import { useState, useActionState } from "react";
import { useRouter } from "next/navigation";
import { CheckCircle2, XCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { CodeEditor } from "@/components/shared/code-editor";
import { submitCodingItemAction } from "@/lib/interview-prep/actions";
import type { CodingItem } from "@/lib/server/interview-prep";
import ROUTES from "@/lib/routes";

interface CodingItemPanelProps {
  planId: string;
  roundId: string;
  item: CodingItem;
  itemIndex: number;
  isLast: boolean;
}

interface State { error?: string }

export function CodingItemPanel({ planId, roundId, item, itemIndex, isLast }: CodingItemPanelProps) {
  const router = useRouter();
  const [code, setCode] = useState(item.submitted_code || item.starter_code);

  const [state, formAction, pending] = useActionState(
    async (_prev: State | null): Promise<State | null> => {
      const result = await submitCodingItemAction(planId, roundId, item.id, code, item.language);
      if (!result.ok) return { error: result.error };
      if (isLast) {
        router.push(ROUTES.interviewPrepPlan(planId));
      } else {
        router.push(`${ROUTES.interviewPrepCoding(planId)}?item=${itemIndex + 1}`);
      }
      return null;
    },
    null,
  );

  const visibleCases = item.test_cases.filter((c) => !c.hidden);

  return (
    <div className="flex min-h-[520px] flex-col overflow-hidden rounded-[--radius-lg] border border-border lg:min-h-[640px] lg:flex-row">
      <div className="flex flex-col gap-5 overflow-y-auto border-b border-border p-5 lg:w-[42%] lg:border-b-0 lg:border-r">
        <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
          Problem {itemIndex + 1} · {item.skill}
        </p>
        <p className="whitespace-pre-wrap text-sm leading-relaxed">{item.prompt}</p>

        {visibleCases.length > 0 && (
          <div className="flex flex-col gap-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Examples</p>
            {visibleCases.map((c, i) => (
              <div className="flex flex-col gap-2" key={i}>
                <p className="text-xs font-medium text-muted-foreground">Example {i + 1}</p>
                <div className="rounded-[--radius-md] bg-muted p-3">
                  <p className="mb-1 text-xs text-muted-foreground">Input</p>
                  <pre className="overflow-x-auto font-mono text-xs text-foreground">{c.stdin}</pre>
                </div>
                <div className="rounded-[--radius-md] bg-muted p-3">
                  <p className="mb-1 text-xs text-muted-foreground">Expected output</p>
                  <pre className="overflow-x-auto font-mono text-xs text-foreground">{c.expected}</pre>
                </div>
              </div>
            ))}
          </div>
        )}

        {item.run_result && (
          <div className="card-base flex items-center gap-2 p-3">
            {item.passed ? (
              <CheckCircle2 aria-hidden className="h-5 w-5 shrink-0 text-primary" />
            ) : (
              <XCircle aria-hidden className="h-5 w-5 shrink-0 text-destructive" />
            )}
            <span className="text-sm">
              {item.run_result.tests_passed}/{item.run_result.tests_total} test cases passed
            </span>
          </div>
        )}
      </div>

      <div className="flex min-h-[300px] flex-1 flex-col lg:min-h-0">
        <div className="flex items-center justify-between border-b border-border bg-muted/50 px-3 py-1.5">
          <span className="text-xs font-medium text-muted-foreground">{item.language}</span>
        </div>
        <CodeEditor
          className="flex-1"
          height="100%"
          language={item.language}
          value={code}
          onChange={(v) => setCode(v ?? "")}
        />
        <div className="flex items-center justify-between gap-3 border-t border-border p-3">
          {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
          <Button
            className="ml-auto"
            disabled={pending || !code.trim()}
            onClick={() => formAction()}
          >
            {pending ? "Running…" : isLast ? "Submit & finish" : "Submit & next"}
          </Button>
        </div>
      </div>
    </div>
  );
}
