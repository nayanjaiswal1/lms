"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { LabTaskPanel } from "@/app/demo/tour/lab-shell";
import { LivePreview } from "@/app/demo/tour/live-preview";
import { DEMO_DEBUG_LAB as LAB } from "@/app/demo/tour/mock-data";
import { cn } from "@/lib/utils";

interface DebugLabDemoProps {
  nonce: string;
}

interface RunState {
  source: string;
  run: number;
  results: boolean[] | null;
}

const PREVIEW_HTML = '<h3>Your cart</h3><p id="total">…</p>';

export function DebugLabDemo({ nonce }: DebugLabDemoProps) {
  const [code, setCode] = useState<string>(LAB.buggy);
  const [state, setState] = useState<RunState>({ source: LAB.buggy, run: 0, results: null });

  const passed = new Set(LAB.tasks.filter((_, i) => state.results?.[i] === true).map((t) => t.id));
  const allPassed = passed.size === LAB.tasks.length;

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1>{LAB.title}</h1>
        <p className="text-muted-foreground">{LAB.brief}</p>
      </div>

      <div className="grid gap-4 lg:grid-cols-[18rem_1fr]">
        <LabTaskPanel hints={LAB.hints} passed={passed} tasks={LAB.tasks} />

        <div className="grid min-w-0 gap-4 xl:grid-cols-2">
          <section aria-label="Editor" className="card-base flex min-w-0 flex-col gap-3 p-5">
            <p className="font-mono text-xs text-muted-foreground">{LAB.file}</p>
            <Textarea
              aria-label={`Edit ${LAB.file}`}
              className="min-h-64 font-mono text-sm"
              spellCheck={false}
              value={code}
              onChange={(e) => setCode(e.target.value)}
            />
            <div className="flex items-center justify-between gap-2">
              <p className={cn("text-sm", allPassed ? "text-success" : "text-muted-foreground")}>
                {allPassed ? "All tasks passed — lab complete." : "Edit, then Run."}
              </p>
              <div className="flex gap-2">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => { setCode(LAB.buggy); setState((s) => ({ source: LAB.buggy, run: s.run + 1, results: null })); }}
                >
                  Reset
                </Button>
                <Button size="sm" onClick={() => setState((s) => ({ source: code, run: s.run + 1, results: null }))}>Run</Button>
              </div>
            </div>
          </section>

          <section aria-label="Live preview" className="card-base flex min-w-0 flex-col gap-3 p-5">
            <p className="text-xs font-medium uppercase tracking-wider text-muted-foreground">Live preview</p>
            <LivePreview
              css=""
              harness={LAB.harness}
              html={PREVIEW_HTML}
              nonce={nonce}
              runKey={state.run}
              script={state.source}
              onResults={(results) => setState((s) => ({ ...s, results }))}
            />
          </section>
        </div>
      </div>
    </div>
  );
}
