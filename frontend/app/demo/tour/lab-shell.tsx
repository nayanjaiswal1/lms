"use client";

import { useState } from "react";
import { CheckCircle2, Lightbulb } from "lucide-react";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

interface LabTask {
  id: string;
  title: string;
}

interface LabTaskPanelProps {
  tasks: LabTask[];
  passed: ReadonlySet<string>;
  hints: string[];
}

// Task checklist + 3-level hint ladder shared by every demo lab workspace.
export function LabTaskPanel({ tasks, passed, hints }: LabTaskPanelProps) {
  const [hintLevel, setHintLevel] = useState(0);

  return (
    <section aria-label="Tasks" className="card-base flex flex-col gap-3 p-5">
      <p className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
        Tasks · {passed.size}/{tasks.length}
      </p>
      <ul className="flex flex-col gap-3">
        {tasks.map((t, i) => {
          const ok = passed.has(t.id);
          return (
            <li className="flex items-start gap-3 text-sm" key={t.id}>
              <span
                className={cn(
                  "flex h-7 w-7 shrink-0 items-center justify-center rounded-full border text-xs font-semibold tabular-nums",
                  ok ? "border-success/40 bg-success/10 text-success" : "border-border text-muted-foreground",
                )}
              >
                {ok ? <CheckCircle2 aria-hidden className="h-4 w-4" /> : i + 1}
              </span>
              <span className="pt-0.5">{t.title}</span>
            </li>
          );
        })}
      </ul>

      {hintLevel > 0 && (
        <div className="ai-surface flex flex-col gap-1 p-3 text-sm">
          <span className="ai-badge self-start">Hint {hintLevel}/{hints.length}</span>
          {hints[hintLevel - 1]}
        </div>
      )}
      <Button disabled={hintLevel >= hints.length} size="sm" variant="outline" onClick={() => setHintLevel((l) => l + 1)}>
        <Lightbulb aria-hidden className="mr-2 h-3.5 w-3.5" />
        Hint ({hintLevel}/{hints.length})
      </Button>
    </section>
  );
}
