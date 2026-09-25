"use client";

import { useState } from "react";
import { parseAsInteger, useQueryState } from "nuqs";
import { CheckCircle2, LayoutGrid, Tag, UserPlus } from "lucide-react";
import { IssueDrawer } from "@/components/gitlab-planning/issue-drawer";
import { IssueRow } from "@/components/gitlab-planning/issue-row";
import type { AeIssue } from "@/lib/server/gitlab-planning";

interface IssueListProps {
  issues: AeIssue[];
  compact: boolean;
  bulk: boolean;
}

const BATCH_ACTIONS = [
  { label: "Mark as Done", icon: CheckCircle2, tone: "tertiary" },
  { label: "Change Assignee", icon: UserPlus, tone: "primary" },
  { label: "Assign Label", icon: Tag, tone: "secondary" },
  { label: "Move Quadrant", icon: LayoutGrid, tone: "error" },
] as const;

export function IssueList({ issues, compact, bulk }: IssueListProps) {
  const [selected, setSelected] = useState(() => new Set(issues.filter((i) => i.selected).map((i) => i.id)));
  // Open drawer lives in the URL (?issue=104) so refresh/share restores it.
  const [openId, setOpenId] = useQueryState("issue", parseAsInteger.withOptions({ scroll: false }));

  const allSelected = issues.length > 0 && issues.every((i) => selected.has(i.id));
  const openIssue = issues.find((i) => i.id === openId) ?? null;

  function toggle(id: number) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  return (
    <>
      {bulk && (
        <div className="flex flex-col justify-between gap-1.5 rounded-xl bg-muted px-2 py-1.5 shadow-card sm:flex-row sm:items-center">
          <div className="flex items-center gap-2">
            <label className="flex cursor-pointer select-none items-center gap-1">
              <input
                checked={allSelected}
                className="size-4 cursor-pointer rounded accent-primary"
                type="checkbox"
                onChange={() => setSelected(allSelected ? new Set() : new Set(issues.map((i) => i.id)))}
              />
              <span className="m-headline-sm text-foreground">Select all {issues.length} issues displayed</span>
            </label>
            <span className="m-label-sm hidden text-muted-foreground md:inline">• {selected.size} selected</span>
          </div>
          <div className="flex flex-wrap items-center gap-1">
            {BATCH_ACTIONS.map(({ label, icon: Icon, tone }) => (
              <button
                className="m-label-md flex h-7 items-center gap-1 rounded-lg bg-card px-1.5 text-foreground shadow-card transition-colors hover:bg-muted disabled:opacity-50"
                disabled={selected.size === 0}
                key={label}
                type="button"
              >
                <Icon aria-hidden className="size-3.5 text-(--mc)" data-mtone={tone} />
                <span>{label}</span>
              </button>
            ))}
          </div>
        </div>
      )}

      {issues.length === 0 ? (
        <div className="m-body-sm rounded-xl bg-card p-8 text-center text-muted-foreground shadow-card">
          No issues match this view.
        </div>
      ) : (
        <ul className="flex flex-col gap-1.5">
          {issues.map((issue) => (
            <IssueRow
              checked={selected.has(issue.id)}
              compact={compact}
              issue={issue}
              key={issue.id}
              onOpen={() => void setOpenId(issue.id)}
              onToggle={() => toggle(issue.id)}
            />
          ))}
        </ul>
      )}

      {openIssue && <IssueDrawer issue={openIssue} key={openIssue.id} onClose={() => void setOpenId(null)} />}
    </>
  );
}
