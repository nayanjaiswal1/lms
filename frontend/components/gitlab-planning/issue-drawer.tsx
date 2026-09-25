"use client";

import { useState } from "react";
import { Bold, Check, Clock, Code, ExternalLink, GitBranch, GitMerge, Link2, Paperclip, Timer, X } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
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
      className="ae-drawer safe-bottom m-0 ml-auto flex h-dvh max-h-dvh w-full max-w-3xl flex-col border-0 border-l border-border/30 bg-card p-0 text-foreground shadow-modal"
      ref={(el) => {
        if (el && !el.open) el.showModal();
      }}
      onClick={(e) => e.target === e.currentTarget && onClose()}
      onClose={onClose}
    >
        <div className="flex flex-col border-b border-border/20 px-4 py-4 sm:px-6">
          <div className="mb-3 flex-between gap-4">
            <div className="flex flex-wrap items-center gap-2">
              <span className="m-label-sm flex items-center gap-1 rounded-full bg-(--m-primary-fixed) px-2 py-0.5 text-xs font-semibold text-(--m-on-primary-fixed)">
                <span className="size-1.5 rounded-full bg-primary" />
                {issue.status}
              </span>
              <span className="m-label-md text-muted-foreground">#{issue.id}</span>
              <QuadrantBadge quadrant={issue.quadrant} />
              <span className="m-label-sm text-(--m-outline-variant)">•</span>
              <span className="text-xs text-muted-foreground">{issue.opened_short}</span>
            </div>
            <div className="flex items-center gap-1">
              <Button aria-label="Copy issue link" size="icon" variant="ghost" type="button" onClick={copyLink}>
                <Link2 aria-hidden className="size-4.5" />
              </Button>
              <Button asChild size="icon" variant="ghost">
                <a aria-label="Open in new tab" href={`${ROUTES.GITLAB_ISSUES}?issue=${issue.id}`} rel="noreferrer" target="_blank">
                  <ExternalLink aria-hidden className="size-4.5" />
                </a>
              </Button>
              <Button aria-label="Close drawer" className="ml-1" size="icon" variant="ghost" type="button" onClick={onClose}>
                <X aria-hidden className="size-5" />
              </Button>
            </div>
          </div>
          <h2 className="m-headline-lg mb-3.5 leading-snug tracking-tight text-foreground" id="issue-drawer-title">
            #{issue.id} {issue.title}
          </h2>
          <dl className="grid grid-cols-2 gap-2 rounded-xl bg-muted px-3 py-2 sm:grid-cols-4">
            <div className="flex flex-col gap-0.5">
              <dt className="m-label-sm text-xs text-muted-foreground">Assignee</dt>
              <dd className="flex items-center gap-1.5 text-xs font-medium text-foreground">
                {issue.assignee ? (
                  <>
                    <span className="flex size-5 items-center justify-center rounded-full bg-(--av-bg) text-xs font-bold text-(--av-fg)" data-mtone={issue.assignee.tone}>{issue.assignee.initial}</span>
                    {issue.assignee.handle}
                  </>
                ) : "Unassigned"}
              </dd>
            </div>
            {meta.map((m) => (
              <div className="flex min-w-0 flex-col gap-0.5" key={m.label}>
                <dt className="m-label-sm text-xs text-muted-foreground">{m.label}</dt>
                <dd className="flex items-center gap-1 truncate text-xs font-medium text-foreground">
                  {m.icon && <Timer aria-hidden className="size-3.5 text-muted-foreground" />}
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
                  tab === t.key ? "border-b-2 border-(--m-primary) text-primary" : "text-muted-foreground hover:text-foreground",
                )}
                key={t.key}
                role="tab"
                type="button"
                onClick={() => setTab(t.key)}
              >
                <span>{t.label}</span>
                {t.count !== undefined && (
                  <span className={cn("rounded-full px-1.5 text-xs", tab === t.key ? "bg-(--m-primary-fixed) text-(--m-on-primary-fixed)" : "bg-muted text-muted-foreground")}>{t.count}</span>
                )}
              </button>
            ))}
          </div>
        </div>

        <div className="flex flex-1 flex-col gap-5 overflow-y-auto px-4 py-4 sm:px-6">
          {!d && (
            <p className="m-body-sm rounded-xl bg-muted p-6 text-center text-muted-foreground">
              No description or steps have been added to this issue yet.
            </p>
          )}

          {d && tab === "overview" && (
            <>
              <MarkdownSplitEditor initialValue={d.markdown} />
              <IssueSteps steps={d.steps} />
              <section aria-label="GitLab integration" className="flex flex-col gap-2">
                <span className="text-xs font-semibold uppercase tracking-tight text-foreground">GitLab Integration</span>
                <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  {[
                    { label: "Branch", value: d.branch, icon: GitBranch },
                    { label: "Merge Request", value: d.merge_request, icon: GitMerge },
                  ].map(({ label, value, icon: Icon }) => (
                    <div className="flex min-w-0 items-center gap-2 rounded-lg bg-muted p-2" key={label}>
                      <Icon aria-hidden className="size-4 shrink-0 text-primary" />
                      <div className="flex min-w-0 flex-col">
                        <span className="m-label-sm text-xs text-muted-foreground">{label}</span>
                        <span className="m-label-md truncate text-foreground">{value}</span>
                      </div>
                    </div>
                  ))}
                </div>
              </section>
            </>
          )}

          {d && (tab === "overview" || tab === "discussion") && (
            <section aria-label="Discussion" className="flex flex-col gap-2">
              <div className="flex-between">
                <span className="text-xs font-semibold uppercase tracking-tight text-foreground">
                  {tab === "overview" ? "Recent Discussion" : "Discussion"} ({d.discussion.length})
                </span>
                {tab === "overview" && <span className="m-label-sm text-muted-foreground">Showing latest</span>}
              </div>
              {(tab === "overview" ? d.discussion.slice(0, 1) : d.discussion).map((c) => (
                <div className="flex gap-2 rounded-lg bg-muted p-3" key={c.id}>
                  <span className="flex size-7 shrink-0 items-center justify-center rounded-full bg-(--av-bg) text-xs font-bold text-(--av-fg)" data-mtone={c.tone}>{c.initial}</span>
                  <div className="flex min-w-0 flex-col gap-0.5">
                    <div className="flex items-center gap-2">
                      <span className="m-headline-sm text-xs text-foreground">{c.author}</span>
                      <span className="m-label-sm text-xs text-muted-foreground">{c.time}</span>
                    </div>
                    <p className="m-body-sm text-foreground">{c.body}</p>
                  </div>
                </div>
              ))}
              <div className="flex flex-col rounded-lg border border-border">
                <Textarea aria-label="Write a comment" className="m-body-sm resize-none border-0 shadow-none" placeholder="Write a quick comment or mention someone..." rows={2} />
                <div className="flex-between border-t border-border px-2 py-1">
                  <div className="flex items-center gap-1 text-muted-foreground">
                    {COMMENT_TOOLS.map(({ label, icon: Icon }) => (
                      <Button aria-label={label} key={label} size="icon" variant="ghost" type="button">
                        <Icon aria-hidden className="size-3.5" />
                      </Button>
                    ))}
                  </div>
                  <Button size="sm" type="button">Comment</Button>
                </div>
              </div>
            </section>
          )}

          {d && tab === "activity" && (
            <ol className="flex flex-col gap-2 border-l border-border/50 pl-4">
              {d.activity.map((a) => (
                <li className="m-body-sm text-foreground" key={a.id}>
                  <span className="m-label-sm mr-2 text-xs text-muted-foreground">{a.time}</span>
                  {a.text}
                </li>
              ))}
            </ol>
          )}

          {d && tab === "mrs" && (
            <div className="flex items-center gap-2 rounded-lg bg-muted p-3">
              <GitMerge aria-hidden className="size-4 text-success" />
              <span className="m-label-md text-foreground">{d.merge_request}</span>
              <span className="m-label-sm ml-auto text-muted-foreground">{d.branch}</span>
            </div>
          )}
        </div>

        <div className="flex-between gap-2 border-t border-border px-4 py-3 sm:px-6">
          <Button variant="ghost" type="button" onClick={onClose}>
            Close
          </Button>
          <div className="flex items-center gap-2">
            <Button variant="outline" type="button">
              <Clock aria-hidden className="size-4" />
              <span>Move to Parked</span>
            </Button>
            <Button type="button">
              <Check aria-hidden className="size-4" />
              <span>Mark as Done</span>
            </Button>
          </div>
        </div>
    </dialog>
  );
}
