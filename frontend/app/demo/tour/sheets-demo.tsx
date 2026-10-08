"use client";

import { useState } from "react";

import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";
import { DEMO_SHEET } from "@/app/demo/tour/mock-data";
import { cn } from "@/lib/utils";

const DIFFICULTY_CLASS: Record<string, string> = {
  easy: "difficulty-beginner",
  medium: "difficulty-intermediate",
  hard: "difficulty-advanced",
};

export function SheetsDemo() {
  const [done, setDone] = useState<Set<string>>(
    () => new Set(DEMO_SHEET.problems.filter((p) => p.done).map((p) => p.id)),
  );
  const total = DEMO_SHEET.problems.length;
  const pct = Math.round((done.size / total) * 100);

  function toggle(id: string) {
    setDone((prev) => {
      const next = new Set(prev);
      if (!next.delete(id)) next.add(id);
      return next;
    });
  }

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1>{DEMO_SHEET.title}</h1>
        <p className="text-muted-foreground">{done.size} of {total} solved · {pct}%</p>
      </div>

      <div className="progress-track">
        <div className="progress-fill" style={{ "--progress": `${pct}%` } as React.CSSProperties} />
      </div>

      <ul className="card-base divide-y divide-border">
        {DEMO_SHEET.problems.map((p) => (
          <li className="flex items-center gap-3 px-5 py-3" key={p.id}>
            <Checkbox
              aria-label={`Mark ${p.title} solved`}
              checked={done.has(p.id)}
              onCheckedChange={() => toggle(p.id)}
            />
            <span className={cn("min-w-0 flex-1 truncate text-sm font-medium", done.has(p.id) && "text-muted-foreground line-through")}>
              {p.title}
            </span>
            <span className="hidden text-xs text-muted-foreground sm:block">{p.topic}</span>
            <Badge className={DIFFICULTY_CLASS[p.difficulty]} variant="outline">{p.difficulty}</Badge>
          </li>
        ))}
      </ul>
    </div>
  );
}
