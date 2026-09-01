"use client";

import { useMemo, useRef } from "react";
import { classifyStructure, type StructureKind } from "@/lib/algo-visualizer/core/narrate";
import { arrayLocals, detectPointers, type PointerInfo, type PrimitiveArrayValue } from "@/lib/algo-visualizer/core/pointer-detect";
import type { Step } from "@/lib/algo-visualizer/core/types";
import { ArraySection } from "./array-chart";
import { StructureView } from "./structure-view";

interface LivePreviewPanelProps {
  steps: Step[];
  stepIndex: number;
  locals: Record<string, unknown>;
  prevLocals: Record<string, unknown> | undefined;
  pointerNames: readonly string[];
  phase: string;
  caption: string;
}

export function LivePreviewPanel({
  steps,
  stepIndex,
  locals,
  prevLocals,
  pointerNames,
  phase,
  caption,
}: LivePreviewPanelProps) {
  const colorMapRef = useRef(new Map<string, PointerInfo["color"]>());
  const arrays = arrayLocals(locals);

  // Classification looks at the whole run, so it scans every step for array
  // names (not just the current one — a variable like "stack" doesn't exist
  // yet in locals at step 0, so limiting the scan to the current step would
  // permanently miss it). `steps` is a stable reference for the run's
  // lifetime (the parent only replaces it on a new run), so this only
  // recomputes when a new run is loaded.
  const kinds = useMemo(() => {
    const names = new Set<string>();
    for (const step of steps) {
      for (const [name] of arrayLocals(step.locals)) names.add(name);
    }
    const map = new Map<string, StructureKind>();
    for (const name of names) map.set(name, classifyStructure(steps, name));
    return map;
  }, [steps]);

  if (arrays.length === 0) {
    return (
      <div className="live-preview-card flex h-full items-center justify-center text-sm text-muted-foreground">
        No array variables to visualize yet.
      </div>
    );
  }

  const pointers = detectPointers(locals, pointerNames, colorMapRef.current);
  const prevArrays = prevLocals ? new Map(arrayLocals(prevLocals)) : new Map<string, PrimitiveArrayValue[]>();

  return (
    <div className="live-preview-card flex flex-col gap-6 overflow-auto">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-destructive">
          <span aria-hidden className="h-1.5 w-1.5 animate-pulse rounded-full bg-destructive" />
          Live Preview
        </div>
        <span className="rounded-pill bg-muted px-2 py-0.5 font-mono text-[11px] text-muted-foreground">
          Step {stepIndex + 1} / {steps.length}
        </span>
      </div>

      <div className="inline-flex w-fit items-center gap-2 self-start rounded-md bg-primary/10 px-3 py-1.5">
        <span className="rounded-sm bg-primary px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide text-primary-foreground">
          {phase}
        </span>
        <span className="font-mono text-xs text-foreground">{caption}</span>
      </div>

      <div className="flex flex-1 flex-col gap-8">
        {arrays.map(([name, values]) => {
          const kind = kinds.get(name) ?? "array";
          if (kind === "array") {
            return <ArraySection key={name} name={name} pointers={pointers} prevValues={prevArrays.get(name)} values={values} />;
          }
          return <StructureView key={name} kind={kind} name={name} values={values} />;
        })}
      </div>
    </div>
  );
}
