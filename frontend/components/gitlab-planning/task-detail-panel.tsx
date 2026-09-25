import Link from "next/link";
import { CalendarDays, ChevronDown, MoreVertical } from "lucide-react";
import { MarkdownFileBox } from "@/components/gitlab-planning/markdown-file-box";
import { StepCard } from "@/components/gitlab-planning/step-card";
import type { AeChangeLogEntry, AeTaskDetail } from "@/lib/server/gitlab-planning";
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
    <section aria-label={`Task: ${task.title}`} className={cn("space-y-5 card-base shadow-card sm:p-5", className)}>
      <div>
        <div className="mb-2 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-2">
            <span className="size-3 rounded-full bg-(--t-dot)" data-tone={task.dot} />
            <h2 className="text-base font-bold text-foreground">{task.title}</h2>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <span className="inline-flex items-center gap-0.5 rounded-full border border-border bg-(--t-50) px-2 py-0.5 text-xs font-medium text-(--t-700)" data-tone="purple">
              {task.status}
              <ChevronDown aria-hidden className="size-3" />
            </span>
            <span className="flex items-center gap-1 text-xs text-muted-foreground">
              <CalendarDays aria-hidden className="size-3.5" />
              {task.due}
            </span>
            <span className="flex size-5 items-center justify-center rounded bg-primary text-xs font-bold text-(--ae-card)">{task.assignee.initial}</span>
            <span className="text-xs font-medium text-foreground">{task.assignee.name}</span>
            <button aria-label="More task actions" className="text-muted-foreground hover:text-muted-foreground" type="button">
              <MoreVertical aria-hidden className="size-4" />
            </button>
          </div>
        </div>
        <p className="text-xs text-muted-foreground">{task.description}</p>
      </div>

      <nav aria-label="Task sections" className="flex gap-6 overflow-x-auto border-b border-border text-xs font-semibold">
        {task.tabs.map((t, i) => (
          <Link
            aria-current={i === activeTab ? "page" : undefined}
            className={cn(
              "whitespace-nowrap pb-2",
              i === activeTab ? "border-b-2 border-(--ae-brand) text-primary" : "text-muted-foreground hover:text-foreground",
            )}
            href={`${ROUTES.GITLAB_PLANNING}?view=task&tab=${i}`}
            key={t.label}
            scroll={false}
          >
            {t.label}
            {t.count !== undefined && ` (${t.count})`}
          </Link>
        ))}
      </nav>

      {tabLabel === "Steps" && (
        <ol className="space-y-5">
          {task.steps.map((step, i) => (
            <StepCard index={i} key={step.id} step={step} />
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
            <div className="rounded-lg bg-accent p-3" key={k}>
              <dt className="text-xs text-muted-foreground">{k}</dt>
              <dd className="font-semibold text-foreground">{v}</dd>
            </div>
          ))}
        </dl>
      )}

      {(tabLabel === "Files" || tabLabel === "Notes (MD)") && (
        <div className="space-y-3">
          {files.map((f) => (
            <MarkdownFileBox key={f.name} markdown={f.markdown} name={f.name} />
          ))}
        </div>
      )}

      {tabLabel === "Logs" && (
        <ul className="space-y-2.5 text-xs">
          {changeLog.map((e) => (
            <li className="flex justify-between gap-2" key={e.id}>
              <span className="text-foreground"><span className="mr-2 text-muted-foreground">{e.time}</span>{e.message}</span>
              <span className="font-medium text-muted-foreground">{e.actor}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
