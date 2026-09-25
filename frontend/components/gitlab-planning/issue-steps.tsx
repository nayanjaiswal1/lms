"use client";

import { useState } from "react";
import { CircleCheck, Clock, Plus, RefreshCw } from "lucide-react";
import type { AeIssueStep } from "@/lib/gitlab-planning/types";
import { cn } from "@/lib/utils";

const NOTE_ICON = { done: CircleCheck, progress: RefreshCw, pending: Clock };

interface IssueStepsProps {
  steps: AeIssueStep[];
}

export function IssueSteps({ steps }: IssueStepsProps) {
  const [checked, setChecked] = useState(() => new Set(steps.filter((s) => s.checked).map((s) => s.id)));
  const pct = steps.length ? Math.round((checked.size / steps.length) * 100) : 0;

  function toggle(id: string) {
    setChecked((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  return (
    <section aria-label="Steps and sub-tasks" className="flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-xs font-semibold uppercase tracking-tight text-(--m-on-surface)">Steps &amp; Sub-tasks</span>
          <span className="m-label-sm rounded-full bg-(--m-primary-fixed) px-1.5 text-[10px] text-(--m-on-primary-fixed)">
            {checked.size} / {steps.length} done
          </span>
        </div>
        <span className="m-label-sm text-(--m-primary)">{pct}% complete</span>
      </div>
      <div className="h-1.5 w-full overflow-hidden rounded-full bg-(--m-sc-high)">
        {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width */}
        <div className="h-1.5 rounded-full bg-(--m-primary) transition-all duration-300" style={{ width: `${pct}%` }} />
      </div>
      <div className="flex flex-col gap-1">
        {steps.map((s) => {
          const Icon = NOTE_ICON[s.note_icon];
          const isChecked = checked.has(s.id);
          return (
            <label key={s.id} className="flex cursor-pointer items-start gap-2 rounded-lg p-2 transition-colors hover:bg-(--m-sc-low)">
              <input type="checkbox" checked={isChecked} onChange={() => toggle(s.id)} className="mt-0.5 size-4 shrink-0 cursor-pointer rounded accent-(--m-primary)" />
              <span className="flex min-w-0 flex-col gap-0.5">
                <span className={cn("m-body-sm", isChecked ? "text-(--m-on-surface-variant) line-through" : "text-(--m-on-surface)")}>{s.label}</span>
                <span data-mtone={s.note_icon === "done" ? "tertiary" : s.note_icon === "progress" ? "primary" : "muted"} className="m-label-sm flex items-center gap-1 text-[10px] text-(--mc)">
                  <Icon className="size-3" aria-hidden /> {s.note}
                </span>
              </span>
            </label>
          );
        })}
      </div>
      <button type="button" className="m-label-sm flex items-center gap-1 self-start rounded-lg px-2 py-1 text-(--m-primary) hover:bg-(--m-sc-low)">
        <Plus className="size-3.5" aria-hidden />
        <span>Add new step item</span>
      </button>
    </section>
  );
}
