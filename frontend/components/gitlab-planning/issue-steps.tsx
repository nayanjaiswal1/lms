"use client";

import { useState } from "react";
import { CircleCheck, Clock, Plus, RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import type { AeIssueStep } from "@/lib/server/gitlab-planning";
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
      <div className="flex-between">
        <div className="flex items-center gap-2">
          <span className="text-xs font-semibold uppercase tracking-tight text-foreground">Steps &amp; Sub-tasks</span>
          <span className="m-label-sm rounded-full bg-(--m-primary-fixed) px-1.5 text-xs text-(--m-on-primary-fixed)">
            {checked.size} / {steps.length} done
          </span>
        </div>
        <span className="m-label-sm text-primary">{pct}% complete</span>
      </div>
      <div className="progress-track">
        {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width */}
        <div className="progress-fill" style={{ width: `${pct}%` }} />
      </div>
      <div className="flex flex-col gap-1">
        {steps.map((s) => {
          const Icon = NOTE_ICON[s.note_icon];
          const isChecked = checked.has(s.id);
          return (
            <label aria-label={s.label} className="flex cursor-pointer items-start gap-2 rounded-lg p-2 transition-colors hover:bg-muted" key={s.id}>
              <Checkbox aria-label={s.label} checked={isChecked} className="mt-0.5 shrink-0" onCheckedChange={() => toggle(s.id)} />
              <span className="flex min-w-0 flex-col gap-0.5">
                <span className={cn("m-body-sm", isChecked ? "text-muted-foreground line-through" : "text-foreground")}>{s.label}</span>
                <span className="m-label-sm flex items-center gap-1 text-xs text-(--mc)" data-mtone={s.note_icon === "done" ? "tertiary" : s.note_icon === "progress" ? "primary" : "muted"}>
                  <Icon aria-hidden className="size-3" /> {s.note}
                </span>
              </span>
            </label>
          );
        })}
      </div>
      <Button className="m-label-sm h-auto self-start px-2 py-1" variant="link" type="button">
        <Plus aria-hidden className="size-3.5" />
        <span>Add new step item</span>
      </Button>
      </button>
    </section>
  );
}
