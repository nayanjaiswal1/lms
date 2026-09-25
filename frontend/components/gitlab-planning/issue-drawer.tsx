"use client";

import { useState } from "react";
import { Bold, Check, Clock, Code, ExternalLink, GitBranch, GitMerge, Link2, Paperclip, Timer, X } from "lucide-react";
import { toast } from "sonner";
import { IssueSteps } from "@/components/gitlab-planning/issue-steps";
import { MarkdownSplitEditor } from "@/components/gitlab-planning/markdown-split-editor";
import { QuadrantBadge } from "@/components/gitlab-planning/quadrant-badge";
import type { AeIssue } from "@/lib/server/gitlab-planning";
import ROUTES from "@/lib/routes";
import { cn } from "@/lib/utils";

const COMMENT_TOOLS = [
  { label: "Bold", icon: Bold },
  { label: "Code", icon: Code },
  { label: "Attach file", icon: Paperclip },
];

type DrawerTab = "overview" | "discussion" | "activity" | "mrs";

interface IssueDrawerProps {
  issue: AeIssue;
  onClose: () => void;
}

export function IssueDrawer({ issue, onClose }: IssueDrawerProps) {
  const [tab, setTab] = useState<DrawerTab>("overview");
  const d = issue.detail;

  const tabs: { key: DrawerTab; label: string; count?: number }[] = [
    { key: "overview", label: "Overview & Steps", count: d?.steps.length },
    { key: "discussion", label: "Discussion", count: d?.discussion.length ?? issue.comments },
    { key: "activity", label: "Activity" },
    { key: "mrs", label: "Related MRs", count: d ? 1 : 0 },
  ];

  const meta = [
    { label: "Milestone", value: issue.milestone },
    { label: "Weight / Est", value: issue.estimate, icon: true },
    { label: "Due Date", value: issue.due },
  ];

  function copyLink() {
    void navigator.clipboard.writeText(`${window.location.origin}${ROUTES.GITLAB_ISSUES}?issue=${issue.id}`);
    toast.success("Issue link copied");
  }

  return (
    // Native modal <dialog>: Esc, focus trap and top-layer backdrop for free,
    // while staying inside the .ae scope so the Stitch tokens still apply.
    // eslint-disable-next-line jsx-a11y/click-events-have-key-events, jsx-a11y/no-noninteractive-element-interactions -- backdrop click-to-close; keyboard users get native Esc via onClose
    <dialog
      aria-labelledby="issue-drawer-title"
      className="ae-drawer safe-bottom m-0 ml-auto flex h-dvh max-h-dvh w-full max-w-3xl flex-col border-0 border-l border-(--m-outline-variant)/30 bg-(--m-sc-lowest) p-0 text-(--m-on-surface) shadow-2xl"
      ref={(el) => {
        if (el && !el.open) el.showModal();
      }}
      onClick={(e) => e.target === e.currentTarget && onClose()}
      onClose={onClose}
    >
        <div className="flex flex-col border-b border-(--m-outline-variant)/20 px-4 py-4 sm:px-6">
          <div className="mb-3 flex items-center justify-between gap-4">
            <div className="flex flex-wrap items-center gap-2">
              <span className="m-label-sm flex items-center gap-1 rounded-full bg-(--m-primary-fixed) px-2 py-0.5 text-[11px] font-semibold text-(--m-on-primary-fixed)">
                <span className="size-1.5 rounded-full bg-(--m-primary)" />
                {issue.status}
              </span>
              <span className="m-label-md text-(--m-on-surface-variant)">#{issue.id}</span>
              <QuadrantBadge quadrant={issue.quadrant} />
              <span className="m-label-sm text-(--m-outline-variant)">•</span>
              <span className="text-xs text-(--m-on-surface-variant)">{issue.opened_short}</span>
            </div>
            <div className="flex items-center gap-1">
              <button aria-label="Copy issue link" className="flex size-8 items-center justify-center rounded-lg text-(--m-on-surface-variant) transition-colors hover:bg-(--m-sc) hover:text-(--m-on-surface)" type="button" onClick={copyLink}>
                <Link2 aria-hidden className="size-4.5" />
              </button>
              <a aria-label="Open in new tab" className="flex size-8 items-center justify-center rounded-lg text-(--m-on-surface-variant) transition-colors hover:bg-(--m-sc) hover:text-(--m-on-surface)" href={`${ROUTES.GITLAB_ISSUES}?issue=${issue.id}`} rel="noreferrer" target="_blank">
                <ExternalLink aria-hidden className="size-4.5" />
              </a>
              <button aria-label="Close drawer" className="ml-1 flex size-8 items-center justify-center rounded-lg text-(--m-on-surface-variant) transition-colors hover:bg-(--m-sc) hover:text-(--m-error)" type="button" onClick={onClose}>
                <X aria-hidden className="size-5" />
              </button>
            </div>
          </div>
          <h2 className="m-headline-lg mb-3.5 leading-snug tracking-tight text-(--m-on-surface)" id="issue-drawer-title">
            #{issue.id} {issue.title}
          </h2>
          <dl className="grid grid-cols-2 gap-2 rounded-xl bg-(--m-sc-low) px-3 py-2 sm:grid-cols-4">
            <div className="flex flex-col gap-0.5">
              <dt className="m-label-sm text-[11px] text-(--m-on-surface-variant)">Assignee</dt>
              <dd className="flex items-center gap-1.5 text-xs font-medium text-(--m-on-surface)">
                {issue.assignee ? (
                  <>
                    <span className="flex size-5 items-center justify-center rounded-full bg-(--av-bg) text-[10px] font-bold text-(--av-fg)" data-mtone={issue.assignee.tone}>{issue.assignee.initial}</span>
                    {issue.assignee.handle}
                  </>
                ) : "Unassigned"}
              </dd>
            </div>
            {meta.map((m) => (
              <div className="flex min-w-0 flex-col gap-0.5" key={m.label}>
                <dt className="m-label-sm text-[11px] text-(--m-on-surface-variant)">{m.label}</dt>
                <dd className="flex items-center gap-1 truncate text-xs font-medium text-(--m-on-surface)">
                  {m.icon && <Timer aria-hidden className="size-3.5 text-(--m-on-surface-variant)" />}
                  {m.value}
                </dd>
              </div>
            ))}
          </dl>
          <div className="mt-3 flex items-center gap-4 overflow-x-auto" role="tablist">
            {tabs.map((t) => (
              <button
                aria-selected={tab === t.key}
                className={cn(
                  "flex shrink-0 items-center gap-1.5 whitespace-nowrap py-1.5 text-xs font-semibold transition-colors",
                  tab === t.key ? "border-b-2 border-(--m-primary) text-(--m-primary)" : "text-(--m-on-surface-variant) hover:text-(--m-on-surface)",
                )}
                key={t.key}
                role="tab"
                type="button"
                onClick={() => setTab(t.key)}
              >
                <span>{t.label}</span>
                {t.count !== undefined && (
                  <span className={cn("rounded-full px-1.5 text-[10px]", tab === t.key ? "bg-(--m-primary-fixed) text-(--m-on-primary-fixed)" : "bg-(--m-sc-high) text-(--m-on-surface-variant)")}>{t.count}</span>
                )}
              </button>
            ))}
          </div>
        </div>

        <div className="flex flex-1 flex-col gap-5 overflow-y-auto px-4 py-4 sm:px-6">
          {!d && (
            <p className="m-body-sm rounded-xl bg-(--m-sc-low) p-6 text-center text-(--m-on-surface-variant)">
              No description or steps have been added to this issue yet.
            </p>
          )}

          {d && tab === "overview" && (
            <>
              <MarkdownSplitEditor initialValue={d.markdown} />
              <IssueSteps steps={d.steps} />
              <section aria-label="GitLab integration" className="flex flex-col gap-2">
                <span className="text-xs font-semibold uppercase tracking-tight text-(--m-on-surface)">GitLab Integration</span>
                <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  {[
                    { label: "Branch", value: d.branch, icon: GitBranch },
                    { label: "Merge Request", value: d.merge_request, icon: GitMerge },
                  ].map(({ label, value, icon: Icon }) => (
                    <div className="flex min-w-0 items-center gap-2 rounded-lg bg-(--m-sc-low) p-2" key={label}>
                      <Icon aria-hidden className="size-4 shrink-0 text-(--m-primary)" />
                      <div className="flex min-w-0 flex-col">
                        <span className="m-label-sm text-[10px] text-(--m-on-surface-variant)">{label}</span>
                        <span className="m-label-md truncate text-(--m-on-surface)">{value}</span>
                      </div>
                    </div>
                  ))}
                </div>
              </section>
            </>
          )}

          {d && (tab === "overview" || tab === "discussion") && (
            <section aria-label="Discussion" className="flex flex-col gap-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold uppercase tracking-tight text-(--m-on-surface)">
                  {tab === "overview" ? "Recent Discussion" : "Discussion"} ({d.discussion.length})
                </span>
                {tab === "overview" && <span className="m-label-sm text-(--m-on-surface-variant)">Showing latest</span>}
              </div>
              {(tab === "overview" ? d.discussion.slice(0, 1) : d.discussion).map((c) => (
                <div className="flex gap-2 rounded-lg bg-(--m-sc-low) p-3" key={c.id}>
                  <span className="flex size-7 shrink-0 items-center justify-center rounded-full bg-(--av-bg) text-xs font-bold text-(--av-fg)" data-mtone={c.tone}>{c.initial}</span>
                  <div className="flex min-w-0 flex-col gap-0.5">
                    <div className="flex items-center gap-2">
                      <span className="m-headline-sm text-xs text-(--m-on-surface)">{c.author}</span>
                      <span className="m-label-sm text-[10px] text-(--m-on-surface-variant)">{c.time}</span>
                    </div>
                    <p className="m-body-sm text-(--m-on-surface)">{c.body}</p>
                  </div>
                </div>
              ))}
              <div className="flex flex-col rounded-lg border border-(--m-outline-variant)/40">
                <textarea aria-label="Write a comment" className="m-body-sm resize-none bg-transparent p-2 text-(--m-on-surface) placeholder:text-(--m-on-surface-variant) focus:outline-none" placeholder="Write a quick comment or mention someone..." rows={2} />
                <div className="flex items-center justify-between border-t border-(--m-outline-variant)/30 px-2 py-1">
                  <div className="flex items-center gap-1 text-(--m-on-surface-variant)">
                    {COMMENT_TOOLS.map(({ label, icon: Icon }) => (
                      <button aria-label={label} className="rounded p-1 hover:bg-(--m-sc) hover:text-(--m-on-surface)" key={label} type="button">
                        <Icon aria-hidden className="size-3.5" />
                      </button>
                    ))}
                  </div>
                  <button className="m-headline-sm rounded-lg bg-(--m-primary) px-3 py-1 text-xs text-(--m-sc-lowest) hover:bg-(--m-primary-container)" type="button">Comment</button>
                </div>
              </div>
            </section>
          )}

          {d && tab === "activity" && (
            <ol className="flex flex-col gap-2 border-l border-(--m-outline-variant)/50 pl-4">
              {d.activity.map((a) => (
                <li className="m-body-sm text-(--m-on-surface)" key={a.id}>
                  <span className="m-label-sm mr-2 text-[10px] text-(--m-on-surface-variant)">{a.time}</span>
                  {a.text}
                </li>
              ))}
            </ol>
          )}

          {d && tab === "mrs" && (
            <div className="flex items-center gap-2 rounded-lg bg-(--m-sc-low) p-3">
              <GitMerge aria-hidden className="size-4 text-(--m-tertiary)" />
              <span className="m-label-md text-(--m-on-surface)">{d.merge_request}</span>
              <span className="m-label-sm ml-auto text-(--m-on-surface-variant)">{d.branch}</span>
            </div>
          )}
        </div>

        <div className="flex items-center justify-between gap-2 border-t border-(--m-outline-variant)/20 px-4 py-3 sm:px-6">
          <button className="m-headline-sm rounded-lg px-3 py-1.5 text-(--m-on-surface-variant) hover:bg-(--m-sc-low) hover:text-(--m-on-surface)" type="button" onClick={onClose}>
            Close
          </button>
          <div className="flex items-center gap-2">
            <button className="m-headline-sm flex items-center gap-1 rounded-lg bg-(--m-sc-low) px-3 py-1.5 text-(--m-on-surface) hover:bg-(--m-sc)" type="button">
              <Clock aria-hidden className="size-4" />
              <span>Move to Parked</span>
            </button>
            <button className="m-headline-sm flex items-center gap-1 rounded-lg bg-(--m-primary) px-3 py-1.5 text-(--m-sc-lowest) hover:bg-(--m-primary-container)" type="button">
              <Check aria-hidden className="size-4" />
              <span>Mark as Done</span>
            </button>
          </div>
        </div>
    </dialog>
  );
}
