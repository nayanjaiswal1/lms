import Link from "next/link";
import { AlertOctagon, Bug, Clock, GraduationCap, UserX, GitBranchPlus, MessageSquareWarning } from "lucide-react";

import ROUTES from "@/lib/routes";
import type { NeedsAttention } from "@/lib/workspace/types";

interface NeedsAttentionListProps {
  workspaceId: string;
  needsAttention: NeedsAttention;
}

interface Section {
  key: string;
  label: string;
  Icon: typeof AlertOctagon;
  listQuery: string;
  rows: { href: string; label: string; detail: string }[];
}

// contract-phase4.md 04 §5 ("Needs attention list (rows link to the filtered
// list view")) + models_phase4.go's own comment on AttentionItem ("the UI
// links to the filtered list"): each section heading links to the closest
// equivalent /list filter ItemFilters actually supports; individual rows
// additionally deep-link straight to the item itself, since a manager acting
// on one flagged item shouldn't have to find it again in a filtered list.
export function NeedsAttentionList({ workspaceId, needsAttention: na }: NeedsAttentionListProps) {
  const itemHref = (key: string) => ROUTES.workspaceItem(workspaceId, key);
  const listHref = (qs: string) => `${ROUTES.workspaceList(workspaceId)}?${qs}`;

  const sections: Section[] = [
    {
      key: "blocked",
      label: "Blocked",
      Icon: AlertOctagon,
      listQuery: "status=blocked",
      rows: na.blocked_items.map((a) => ({ href: itemHref(a.item.key), label: `${a.item.key} — ${a.item.title}`, detail: a.detail })),
    },
    {
      key: "overdue",
      label: "Overdue",
      Icon: Clock,
      listQuery: "",
      rows: na.overdue_items.map((a) => ({ href: itemHref(a.item.key), label: `${a.item.key} — ${a.item.title}`, detail: a.detail })),
    },
    {
      key: "stale_reviews",
      label: "Spec reviews waiting",
      Icon: MessageSquareWarning,
      listQuery: "type=feature",
      rows: na.stale_reviews.map((a) => ({ href: itemHref(a.item.key), label: `${a.item.key} — ${a.item.title}`, detail: a.detail })),
    },
    {
      key: "bugs",
      label: "Open S1/S2 bugs",
      Icon: Bug,
      listQuery: "type=bug",
      rows: na.open_s1_s2_bugs.map((a) => ({ href: itemHref(a.item.key), label: `${a.item.key} — ${a.item.title}`, detail: a.detail })),
    },
    {
      key: "onboarding",
      label: "Stuck onboarding",
      Icon: GraduationCap,
      listQuery: "",
      rows: na.stuck_onboarding.map((a) => ({ href: ROUTES.workspaceOnboarding(workspaceId), label: a.person.name, detail: a.detail })),
    },
    {
      key: "inactive",
      label: "Inactive members",
      Icon: UserX,
      listQuery: "",
      rows: na.inactive_members.map((a) => ({ href: ROUTES.workspaceMembers(workspaceId), label: a.person.name, detail: a.detail })),
    },
    {
      key: "leaderless",
      label: "Leaderless tracks",
      Icon: GitBranchPlus,
      listQuery: "",
      rows: na.leaderless_tracks.map((t) => ({ href: ROUTES.workspaceTracks(workspaceId), label: t.name, detail: "No lead assigned" })),
    },
  ].filter((s) => s.rows.length > 0);

  if (sections.length === 0) {
    return (
      <div className="empty-state py-8">
        <p className="text-sm text-muted-foreground">Nothing needs attention right now.</p>
      </div>
    );
  }

  return (
    <div className="grid-responsive-2 gap-4">
      {sections.map(({ key, label, Icon, listQuery, rows }) => (
        <div className="card-base flex flex-col gap-2" key={key}>
          <div className="flex items-center justify-between">
            <h3 className="flex items-center gap-1.5 text-sm font-semibold">
              <Icon aria-hidden className="h-4 w-4 text-muted-foreground" />
              {label} ({rows.length})
            </h3>
            {listQuery && (
              <Link className="text-xs text-primary underline underline-offset-2" href={listHref(listQuery)}>
                View list
              </Link>
            )}
          </div>
          <ul className="flex flex-col gap-1.5">
            {rows.slice(0, 5).map((row, i) => (
              <li key={`${key}-${i}`}>
                <Link className="block truncate text-sm text-foreground hover:underline" href={row.href}>
                  {row.label}
                </Link>
                <p className="truncate text-xs text-muted-foreground">{row.detail}</p>
              </li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
}
