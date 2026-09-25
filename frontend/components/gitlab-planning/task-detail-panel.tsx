import Link from "next/link";
import { CalendarDays, ChevronDown, MoreVertical } from "lucide-react";
import { MarkdownFileBox } from "@/components/gitlab-planning/markdown-file-box";
import { StepCard } from "@/components/gitlab-planning/step-card";
import type { AeChangeLogEntry, AeTaskDetail } from "@/lib/gitlab-planning/types";
import ROUTES from "@/lib/routes";
import { cn } from "@/lib/utils";

interface TaskDetailPanelProps {
  task: AeTaskDetail;
  changeLog: AeChangeLogEntry[];
  /** Index into task.tabs (URL `?tab=`), 0 = Steps. */
  activeTab: number;
  className?: string;
}

export function TaskDetailPanel({ task, changeLog, activeTab, className }: TaskDetailPanelProps) {
  const files = task.steps.flatMap((s) => (s.file ? [s.file] : []));
  const tabLabel = task.tabs[activeTab]?.label ?? "Steps";

  return (
    <section aria-label={`Task: ${task.title}`} className={cn("space-y-5 rounded-2xl border border-(--ae-line)/80 bg-(--ae-card) p-4 shadow-sm sm:p-5", className)}>
      <div>
        <div className="mb-2 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-2">
            <span data-tone={task.dot} className="size-3 rounded-full bg-(--t-dot)" />
            <h2 className="text-base font-bold text-(--ae-ink)">{task.title}</h2>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <span data-tone="purple" className="inline-flex items-center gap-0.5 rounded-full border border-(--t-200) bg-(--t-50) px-2 py-0.5 text-xs font-medium text-(--t-700)">
              {task.status}
              <ChevronDown className="size-3" aria-hidden />
            </span>
            <span className="flex items-center gap-1 text-xs text-(--ae-muted)">
              <CalendarDays className="size-3.5" aria-hidden />
              {task.due}
            </span>
            <span className="flex size-5 items-center justify-center rounded bg-(--ae-brand) text-[10px] font-bold text-(--ae-card)">{task.assignee.initial}</span>
            <span className="text-xs font-medium text-(--ae-body)">{task.assignee.name}</span>
            <button type="button" aria-label="More task actions" className="text-(--ae-faint) hover:text-(--ae-dim)">
              <MoreVertical className="size-4" aria-hidden />
            </button>
          </div>
        </div>
        <p className="text-xs text-(--ae-muted)">{task.description}</p>
      </div>

      <nav aria-label="Task sections" className="flex gap-6 overflow-x-auto border-b border-(--ae-line) text-xs font-semibold">
        {task.tabs.map((t, i) => (
          <Link
            key={t.label}
            href={`${ROUTES.GITLAB_PLANNING}?view=task&tab=${i}`}
            scroll={false}
            aria-current={i === activeTab ? "page" : undefined}
            className={cn(
              "whitespace-nowrap pb-2",
              i === activeTab ? "border-b-2 border-(--ae-brand) text-(--ae-brand)" : "text-(--ae-muted) hover:text-(--ae-text)",
            )}
          >
            {t.label}
            {t.count !== undefined && ` (${t.count})`}
          </Link>
        ))}
      </nav>

      {tabLabel === "Steps" && (
        <ol className="space-y-5">
          {task.steps.map((step, i) => (
            <StepCard key={step.id} step={step} index={i} />
          ))}
        </ol>
      )}

      {tabLabel === "Details" && (
        <dl className="grid grid-cols-1 gap-3 text-xs sm:grid-cols-2">
          {[
            ["Status", task.status],
            ["Due date", task.due],
            ["Assignee", task.assignee.name],
            ["Steps", String(task.steps.length)],
          ].map(([k, v]) => (
            <div key={k} className="rounded-lg bg-(--ae-hover) p-3">
              <dt className="text-[11px] text-(--ae-faint)">{k}</dt>
              <dd className="font-semibold text-(--ae-text)">{v}</dd>
            </div>
          ))}
        </dl>
      )}

      {(tabLabel === "Files" || tabLabel === "Notes (MD)") && (
        <div className="space-y-3">
          {files.map((f) => (
            <MarkdownFileBox key={f.name} name={f.name} markdown={f.markdown} />
          ))}
        </div>
      )}

      {tabLabel === "Logs" && (
        <ul className="space-y-2.5 text-[11px]">
          {changeLog.map((e) => (
            <li key={e.id} className="flex justify-between gap-2">
              <span className="text-(--ae-body)"><span className="mr-2 text-(--ae-faint)">{e.time}</span>{e.message}</span>
              <span className="font-medium text-(--ae-muted)">{e.actor}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
