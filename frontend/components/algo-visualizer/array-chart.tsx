"use client";

import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import type { PointerInfo, POINTER_COLORS, PrimitiveArrayValue } from "@/lib/algo-visualizer/core/pointer-detect";
import { cn } from "@/lib/utils";

const MAX_BARS = 100;

// Tailwind's scanner needs each class name literally in source — a template
// literal like `text-${color}` would never be picked up at build time.
const POINTER_ARROW_CLASS: Record<(typeof POINTER_COLORS)[number], string> = {
  "habit-blue": "text-habit-blue",
  "habit-orange": "text-habit-orange",
  "habit-aqua": "text-habit-aqua",
  "habit-yellow": "text-habit-yellow",
  "habit-magenta": "text-habit-magenta",
  "habit-green": "text-habit-green",
  "habit-violet": "text-habit-violet",
  "habit-red": "text-habit-red",
};

const POINTER_BAR_CLASS: Record<(typeof POINTER_COLORS)[number], string> = {
  "habit-blue": "bg-habit-blue",
  "habit-orange": "bg-habit-orange",
  "habit-aqua": "bg-habit-aqua",
  "habit-yellow": "bg-habit-yellow",
  "habit-magenta": "bg-habit-magenta",
  "habit-green": "bg-habit-green",
  "habit-violet": "bg-habit-violet",
  "habit-red": "bg-habit-red",
};

export interface ArraySectionProps {
  name: string;
  values: PrimitiveArrayValue[];
  prevValues: PrimitiveArrayValue[] | undefined;
  pointers: PointerInfo[];
}

export function ArraySection({ name, values, prevValues, pointers }: ArraySectionProps) {
  if (values.length > MAX_BARS) {
    return (
      <div>
        <p className="mb-1 font-mono text-xs text-muted-foreground">{name} ({values.length} items — too large to chart)</p>
        <p className="truncate font-mono text-xs text-muted-foreground">[{values.slice(0, 20).join(", ")}, …]</p>
      </div>
    );
  }
  if (values.length === 0) {
    return <p className="font-mono text-xs text-muted-foreground">{name} = []</p>;
  }

  const numeric = values.every((v) => typeof v === "number");
  const numbers = numeric ? (values as number[]) : [];
  const min = numeric ? Math.min(...numbers) : 0;
  const max = numeric ? Math.max(...numbers) : 0;
  const span = max - min || 1;

  const relevant = pointers.filter((p) => p.arrayName === name);
  const byIndex = new Map<number, PointerInfo[]>();
  for (const p of relevant) {
    const list = byIndex.get(p.index) ?? [];
    list.push(p);
    byIndex.set(p.index, list);
  }

  return (
    <div>
      <p className="mb-1 font-mono text-xs text-muted-foreground">{name}</p>
      <div className="relative pt-8">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-7">
          {relevant.map((p) => {
            const stack = byIndex.get(p.index) ?? [];
            const stackPos = stack.findIndex((x) => x.name === p.name);
            return (
              <div
                className="absolute flex flex-col items-center transition-[left] duration-normal ease-smooth motion-reduce:transition-none"
                key={p.name}
                // eslint-disable-next-line no-restricted-syntax -- pointer position is computed per-step from the traced index, not a design token
                style={{
                  left: `calc((100% / ${values.length}) * ${p.index + 0.5})`,
                  transform: "translateX(-50%)",
                  top: `${stackPos * 15}px`,
                }}
              >
                <span className="text-[10px] font-semibold leading-none text-foreground">{p.name}</span>
                <span className={cn("text-xs leading-none", POINTER_ARROW_CLASS[p.color])}>▼</span>
              </div>
            );
          })}
        </div>

        <div className="flex h-32 border-b border-border">
          {values.map((v, i) => {
            const heightPct = numeric ? 12 + (((v as number) - min) / span) * 88 : 60;
            const atIndex = byIndex.get(i) ?? [];
            const changed = prevValues !== undefined && prevValues[i] !== v;
            const barColor =
              changed || atIndex.length >= 2
                ? "bg-primary"
                : atIndex.length === 1
                  ? POINTER_BAR_CLASS[atIndex[0].color]
                  : "bg-muted-foreground/30";
            return (
              <Tooltip key={i}>
                <TooltipTrigger asChild>
                  <div className="flex flex-1 cursor-default flex-col justify-end px-0.5">
                    <div
                      className={cn(
                        "mx-auto w-full max-w-12 rounded-t transition-all duration-normal ease-smooth motion-reduce:transition-none",
                        barColor,
                        changed && "ring-2 ring-warning ring-offset-1 ring-offset-background",
                      )}
                      // eslint-disable-next-line no-restricted-syntax -- bar height is scaled per-step from the traced array's own min/max, not a design token
                      style={{ height: `${heightPct}%` }}
                    />
                  </div>
                </TooltipTrigger>
                <TooltipContent>
                  {name}[{i}] = {String(v)}
                </TooltipContent>
              </Tooltip>
            );
          })}
        </div>
        <div className="flex">
          {values.map((v, i) => (
            <span className="flex-1 truncate px-0.5 text-center font-mono text-[10px] text-muted-foreground" key={i}>
              {String(v)}
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}
