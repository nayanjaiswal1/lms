import { Check, CircleAlert, CircleCheckBig, CircleDot, CirclePause, Clock, Flag, LoaderCircle, MessageCircle, Paperclip, Timer, Trash2, UserX, Zap } from "lucide-react";
import { QuadrantBadge } from "@/components/gitlab-planning/quadrant-badge";
import type { AeIssue, AeMTone, AeStatusIcon } from "@/lib/server/gitlab-planning";
import { cn } from "@/lib/utils";

export const STATUS_ICON: Record<AeStatusIcon, { icon: typeof Zap; tone: AeMTone }> = {
  critical: { icon: CircleAlert, tone: "error" },
  in_progress: { icon: LoaderCircle, tone: "secondary" },
  open: { icon: CircleDot, tone: "muted" },
  urgent: { icon: Zap, tone: "error" },
  ready: { icon: CircleCheckBig, tone: "tertiary" },
  parked: { icon: CirclePause, tone: "muted" },
  scheduled: { icon: Clock, tone: "muted" },
  eliminate: { icon: Trash2, tone: "outline" },
};

const META_ICON = { flag: Flag, check: Check };

interface IssueRowProps {
  issue: AeIssue;
  checked: boolean;
  compact: boolean;
  onToggle: () => void;
  onOpen: () => void;
}

export function IssueRow({ issue, checked, compact, onToggle, onOpen }: IssueRowProps) {
  const status = STATUS_ICON[issue.status_icon];
  const StatusIcon = status.icon;
  const pct = issue.steps_total ? Math.round((issue.steps_done / issue.steps_total) * 100) : 0;

  return (
    <li
      className={cn(
        "group relative flex cursor-pointer flex-col justify-between gap-1.5 rounded-xl bg-card shadow-card transition-all hover:bg-muted hover:shadow-raised md:flex-row md:items-center",
        compact ? "p-2" : "p-4",
      )}
    >
      <div className="flex min-w-0 items-start gap-2">
        <input
          aria-label={`Select issue #${issue.id}`}
          checked={checked}
          className="relative z-raised mt-1 size-4 shrink-0 cursor-pointer rounded accent-primary"
          type="checkbox"
          onChange={onToggle}
        />
        <span className="mt-0.5 shrink-0 text-(--mc)" data-mtone={status.tone} title={issue.status_title}>
          <StatusIcon aria-hidden className="size-4.5" />
        </span>
        <div className="flex min-w-0 flex-col gap-1">
          <div className="flex flex-wrap items-center gap-1">
            {/* Stretched button: its ::after covers the row, so the whole card opens the drawer. */}
            <button className="m-headline-md text-left after:absolute after:inset-0 after:rounded-xl tracking-tight text-foreground transition-colors hover:text-primary" type="button" onClick={onOpen}>
              #{issue.id} {issue.title}
            </button>
            <QuadrantBadge quadrant={issue.quadrant} />
            {issue.labels.map((l) => (
              <span className="m-label-sm rounded-full bg-(--mc-bg) px-2 text-xs text-(--mc-fg)" data-mtone={l.tone} key={l.text}>
                {l.text}
              </span>
            ))}
          </div>
          <div className="m-body-sm flex flex-wrap items-center gap-1 text-muted-foreground">
            <span>
              {issue.opened}
              {issue.author && <> by <strong className="font-medium text-foreground">{issue.author}</strong></>}
            </span>
            {issue.meta.map((m) => {
              const Icon = m.icon ? META_ICON[m.icon] : null;
              return (
                <span className="flex items-center gap-1" key={m.text}>
                  <span aria-hidden>•</span>
                  <span className={cn("flex items-center gap-0.5", m.tone && "text-(--mc)")} data-mtone={m.tone}>
                    {Icon && <Icon aria-hidden className="size-3.5" />}
                    {m.text}
                  </span>
                </span>
              );
            })}
          </div>
        </div>
      </div>

      <div className="flex shrink-0 items-center gap-2 self-end pl-7 md:self-center md:pl-0">
        <div className="flex w-28 flex-col gap-1" title={issue.steps_total ? `${issue.steps_done} of ${issue.steps_total} step items completed` : "No sub-steps created"}>
          <div className="m-label-sm flex-between text-xs text-muted-foreground" data-mtone={issue.progress_tone}>
            <span>{issue.steps_total ? `${issue.steps_done}/${issue.steps_total} steps` : "0 steps"}</span>
            <span className="font-semibold text-(--mc)">{issue.steps_total ? `${pct}%` : "-"}</span>
          </div>
          <div className="progress-track">
            {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width */}
            <div className="progress-fill" data-mtone={issue.progress_tone} style={{ width: `${pct}%`, background: "var(--mc)" }} />
          </div>
        </div>
        <span className="m-label-sm flex items-center gap-0.5 rounded-lg bg-muted px-2 py-0.5 text-foreground" title={issue.estimate_title}>
          <Timer aria-hidden className="size-3.5 text-muted-foreground" />
          {issue.estimate}
        </span>
        <div className="m-label-sm flex items-center gap-1.5 text-muted-foreground">
          <span className="flex items-center gap-0.5" title={`${issue.comments} comments`}>
            <MessageCircle aria-hidden className="size-3.5" /> {issue.comments}
          </span>
          {issue.files > 0 && (
            <span className="flex items-center gap-0.5" title={`${issue.files} attached files`}>
              <Paperclip aria-hidden className="size-3.5" /> {issue.files}
            </span>
          )}
        </div>
        {issue.assignee ? (
          <span className="flex items-center gap-1.5 pl-1" title={`Assigned to ${issue.assignee.name}`}>
            <span className="flex size-7 items-center justify-center rounded-full bg-(--av-bg) text-xs font-bold text-(--av-fg) ring-2 ring-border" data-mtone={issue.assignee.tone}>
              {issue.assignee.initial}
            </span>
            <span className="m-body-sm hidden text-foreground xl:inline">{issue.assignee.name}</span>
          </span>
        ) : (
          <span className="flex items-center gap-1.5 pl-1" title="Unassigned">
            <span className="flex size-7 items-center justify-center rounded-full bg-muted text-muted-foreground ring-2 ring-border">
              <UserX aria-hidden className="size-3.5" />
            </span>
            <span className="m-body-sm hidden text-muted-foreground xl:inline">Unassigned</span>
          </span>
        )}
      </div>
    </li>
  );
}
