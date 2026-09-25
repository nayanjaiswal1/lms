"use client";

import { useState } from "react";
import { parseAsInteger, useQueryState } from "nuqs";
import { CheckCircle2, LayoutGrid, Tag, UserPlus } from "lucide-react";
import { IssueDrawer } from "@/components/gitlab-planning/issue-drawer";
import { IssueRow } from "@/components/gitlab-planning/issue-row";
import type { AeIssue } from "@/lib/gitlab-planning/types";

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
        <div className="flex flex-col justify-between gap-1.5 rounded-xl bg-(--m-sc-low) px-2 py-1.5 shadow-2xs sm:flex-row sm:items-center">
          <div className="flex items-center gap-2">
            <label className="flex cursor-pointer select-none items-center gap-1">
              <input
                type="checkbox"
                checked={allSelected}
                onChange={() => setSelected(allSelected ? new Set() : new Set(issues.map((i) => i.id)))}
                className="size-4 cursor-pointer rounded accent-(--m-primary)"
              />
              <span className="m-headline-sm text-(--m-on-surface)">Select all {issues.length} issues displayed</span>
            </label>
            <span className="m-label-sm hidden text-(--m-on-surface-variant) md:inline">• {selected.size} selected</span>
          </div>
          <div className="flex flex-wrap items-center gap-1">
            {BATCH_ACTIONS.map(({ label, icon: Icon, tone }) => (
              <button
                key={label}
                type="button"
                disabled={selected.size === 0}
                className="m-label-md flex h-7 items-center gap-1 rounded-lg bg-(--m-sc-lowest) px-1.5 text-(--m-on-surface) shadow-2xs transition-colors hover:bg-(--m-sc) disabled:opacity-50"
              >
                <Icon data-mtone={tone} className="size-3.5 text-(--mc)" aria-hidden />
                <span>{label}</span>
              </button>
            ))}
          </div>
        </div>
      )}

      {issues.length === 0 ? (
        <div className="m-body-sm rounded-xl bg-(--m-sc-lowest) p-8 text-center text-(--m-on-surface-variant) shadow-sm">
          No issues match this view.
        </div>
      ) : (
        <ul className="flex flex-col gap-1.5">
          {issues.map((issue) => (
            <IssueRow
              key={issue.id}
              issue={issue}
              compact={compact}
              checked={selected.has(issue.id)}
              onToggle={() => toggle(issue.id)}
              onOpen={() => void setOpenId(issue.id)}
            />
          ))}
        </ul>
      )}

      {openIssue && <IssueDrawer key={openIssue.id} issue={openIssue} onClose={() => void setOpenId(null)} />}
    </>
  );
}
