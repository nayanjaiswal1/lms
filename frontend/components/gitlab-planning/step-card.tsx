"use client";

import { useState } from "react";
import { Check, Clock, LoaderCircle, MoreVertical, Timer } from "lucide-react";
import { MarkdownFileBox } from "@/components/gitlab-planning/markdown-file-box";
import type { AeStep, AeTone } from "@/lib/server/gitlab-planning";
import { cn } from "@/lib/utils";

interface StepCardProps {
  step: AeStep;
  index: number;
}

type StepState = "completed" | "in_progress" | "not_started";

const STATE: Record<StepState, { label: string; tone: AeTone; icon: typeof Check }> = {
  completed: { label: "Completed", tone: "emerald", icon: Check },
  in_progress: { label: "In Progress", tone: "blue", icon: LoaderCircle },
  not_started: { label: "Not Started", tone: "slate", icon: Clock },
};

// Step status follows its checklist, exactly as the Stitch prototype did.
export function stepState(done: number, total: number): StepState {
  if (total > 0 && done === total) return "completed";
  return done > 0 ? "in_progress" : "not_started";
}

export function StepCard({ step, index }: StepCardProps) {
  const [checked, setChecked] = useState(() => new Set(step.subtasks.filter((s) => s.checked).map((s) => s.id)));
  const [tab, setTab] = useState(0);

  const total = step.subtasks.length;
  const done = checked.size;
  const percent = total ? Math.round((done / total) * 100) : 0;
  const state = stepState(done, total);
  const { label, tone, icon: StateIcon } = STATE[state];
  const accent: AeTone = state === "completed" ? "emerald" : "blue";

  function toggle(id: string) {
    setChecked((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  const activeTab = step.sub_tabs[tab]?.label ?? "Content";

  return (
    <li className="flex items-start gap-3" data-tone={tone}>
      <div
        className={cn(
          "mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full bg-(--t-50) text-xs font-bold",
          state === "in_progress" ? "border-2 border-(--t-500) text-(--t-600)" : "border border-(--t-300) text-(--t-700)",
          state === "not_started" && "bg-(--t-100) text-(--t-600)",
        )}
      >
        {index + 1}
      </div>
      <div className="min-w-0 flex-1 space-y-3 rounded-xl border border-(--ae-line)/90 bg-(--ae-card) p-3.5 shadow-2xs">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
          <div className="flex items-start gap-2">
            <div className="mt-0.5 flex size-4 shrink-0 items-center justify-center rounded-full bg-(--t-500) text-(--ae-card)">
              <StateIcon aria-hidden className="size-2.5" strokeWidth={3} />
            </div>
            <div>
              <h4 className="text-xs font-bold leading-none text-(--ae-ink)">{step.title}</h4>
              <p className="mt-1 text-[11px] text-(--ae-muted)">{step.description}</p>
            </div>
          </div>
          <div className="flex items-center gap-2 pl-6 sm:pl-0">
            <span className="whitespace-nowrap rounded-full border border-(--t-200) bg-(--t-50) px-2 py-0.5 text-[10px] font-semibold text-(--t-700)">{label}</span>
            <span className="flex items-center gap-0.5 text-[10px] text-(--ae-faint)">
              <Timer aria-hidden className="size-3" /> {step.estimate}
            </span>
            <button aria-label={`More actions for ${step.title}`} className="text-(--ae-faint) hover:text-(--ae-dim)" type="button">
              <MoreVertical aria-hidden className="size-4" />
            </button>
          </div>
        </div>

        {step.sub_tabs.length > 0 && (
          <div className="flex gap-4 border-b border-(--ae-soft) pt-1 text-[11px] font-medium" role="tablist">
            {step.sub_tabs.map((t, i) => (
              <button
                aria-selected={i === tab}
                className={cn(
                  "pb-1",
                  i === tab ? "border-b-2 border-(--ae-brand) font-semibold text-(--ae-brand)" : "text-(--ae-faint) hover:text-(--ae-dim)",
                )}
                key={t.label}
                role="tab"
                type="button"
                onClick={() => setTab(i)}
              >
                {t.label}
                {t.count !== undefined && <span className="ml-0.5 text-[10px]">{t.count}</span>}
              </button>
            ))}
          </div>
        )}

        {activeTab === "Content" && (
          <div className="space-y-2 pt-0.5">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-1.5">
                <span className="text-[11px] font-bold uppercase tracking-wider text-(--ae-text)">Sub-tasks</span>
                <span className="rounded-full border border-(--t-200) bg-(--t-50) px-1.5 py-0.5 text-[10px] font-semibold text-(--t-700)">
                  {done}/{total} completed
                </span>
              </div>
              <span className="text-[10px] font-medium text-(--ae-faint)">{percent}%</span>
            </div>
            <div className="h-1.5 w-full overflow-hidden rounded-full bg-(--ae-soft)">
              {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width */}
              <div className="h-full rounded-full bg-(--t-500) transition-all duration-300" data-tone={accent} style={{ width: `${percent}%` }} />
            </div>
            <ul className="space-y-1.5 pt-1">
              {step.subtasks.map((s) => {
                const isChecked = checked.has(s.id);
                return (
                  <li key={s.id}>
                    <button
                      aria-checked={isChecked}
                      className="flex w-full select-none items-center gap-2.5 rounded-lg border border-transparent px-2.5 py-1.5 text-left transition hover:border-(--ae-line)/60 hover:bg-(--ae-hover)"
                      role="checkbox"
                      type="button"
                      onClick={() => toggle(s.id)}
                    >
                      <span
                        className={cn(
                          "flex size-4 shrink-0 items-center justify-center rounded-md border transition-all",
                          isChecked ? "border-(--t-600) bg-(--t-600) text-(--ae-card) shadow-2xs" : "border-(--ae-line-strong) bg-(--ae-card) text-transparent",
                        )}
                        data-tone={accent}
                      >
                        <Check aria-hidden className="size-3" strokeWidth={3} />
                      </span>
                      <span className={cn("flex-1 text-xs transition-all", isChecked ? "text-(--ae-faint) line-through" : "font-medium text-(--ae-body)")}>
                        {s.label}
                      </span>
                      {s.meta &&
                        (s.meta_kind === "active" ? (
                          <span className="rounded bg-(--ae-brand-soft) px-1.5 py-0.5 text-[10px] font-medium text-(--ae-brand)">{s.meta}</span>
                        ) : (
                          <span className="ae-mono text-[10px] text-(--ae-faint)">{s.meta}</span>
                        ))}
                    </button>
                  </li>
                );
              })}
            </ul>
          </div>
        )}

        {(activeTab === "Content" || activeTab === "Files") && step.file && (
          <MarkdownFileBox markdown={step.file.markdown} name={step.file.name} />
        )}

        {activeTab === "Logs" && (
          <ul className="space-y-1 text-[11px] text-(--ae-dim)">
            {step.subtasks.filter((s) => checked.has(s.id)).map((s) => (
              <li className="flex justify-between gap-2" key={s.id}>
                <span>Checked “{s.label}”</span>
                {s.meta && <span className="ae-mono text-(--ae-faint)">{s.meta}</span>}
              </li>
            ))}
            {done === 0 && <li className="text-(--ae-faint)">No activity on this step yet.</li>}
          </ul>
        )}
      </div>
    </li>
  );
}
