"use client";

import { parseAsString, parseAsStringEnum, useQueryStates } from "nuqs";

import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { ITEM_STATUS_LABEL } from "@/lib/workspace/items-constants";
import type { ItemStatus, ItemType, Track } from "@/lib/workspace/types";

const TYPE_VALUES = ["task", "bug", "subtask"] as const;
const STATUS_VALUES: ItemStatus[] = ["todo", "in_progress", "in_review", "testing", "done", "blocked", "reopened", "wont_do"];

interface Assignable {
  user_id: string;
  name: string;
}

interface ItemFiltersProps {
  tracks: Track[];
  members: Assignable[];
  /** List view also filters by status; the board is already split into status columns. */
  showStatus: boolean;
}

/** URL-driven filter bar shared by the Backlog board and the List view
 * (frontend/CLAUDE.md "URL-Driven UI State") — each page's server component
 * reads the same searchParams and refetches. */
export function ItemFilters({ tracks, members, showStatus }: ItemFiltersProps) {
  const [filters, setFilters] = useQueryStates({
    type: parseAsStringEnum<ItemType>([...TYPE_VALUES]),
    status: parseAsStringEnum<ItemStatus>(STATUS_VALUES),
    track: parseAsString,
    assignee: parseAsString,
    q: parseAsString,
  });

  return (
    <div className="flex flex-wrap items-center gap-2">
      <Input
        aria-label="Search items"
        className="w-full sm:w-56"
        placeholder="Search title…"
        value={filters.q ?? ""}
        onChange={(e) => void setFilters({ q: e.target.value || null })}
      />

      <Select value={filters.type ?? "all"} onValueChange={(v) => void setFilters({ type: v === "all" ? null : (v as ItemType) })}>
        <SelectTrigger className="w-full sm:w-[140px]"><SelectValue placeholder="Type" /></SelectTrigger>
        <SelectContent>
          <SelectItem value="all">All types</SelectItem>
          {TYPE_VALUES.map((t) => <SelectItem key={t} value={t}>{t}</SelectItem>)}
        </SelectContent>
      </Select>

      {showStatus && (
        <Select value={filters.status ?? "all"} onValueChange={(v) => void setFilters({ status: v === "all" ? null : (v as ItemStatus) })}>
          <SelectTrigger className="w-full sm:w-[150px]"><SelectValue placeholder="Status" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All statuses</SelectItem>
            {STATUS_VALUES.map((s) => <SelectItem key={s} value={s}>{ITEM_STATUS_LABEL[s]}</SelectItem>)}
          </SelectContent>
        </Select>
      )}

      <Select value={filters.track ?? "all"} onValueChange={(v) => void setFilters({ track: v === "all" ? null : v })}>
        <SelectTrigger className="w-full sm:w-[150px]"><SelectValue placeholder="Track" /></SelectTrigger>
        <SelectContent>
          <SelectItem value="all">All tracks</SelectItem>
          {tracks.map((t) => <SelectItem key={t.id} value={t.id}>{t.name}</SelectItem>)}
        </SelectContent>
      </Select>

      <Select value={filters.assignee ?? "all"} onValueChange={(v) => void setFilters({ assignee: v === "all" ? null : v })}>
        <SelectTrigger className="w-full sm:w-[160px]"><SelectValue placeholder="Assignee" /></SelectTrigger>
        <SelectContent>
          <SelectItem value="all">Everyone</SelectItem>
          {members.map((m) => <SelectItem key={m.user_id} value={m.user_id}>{m.name}</SelectItem>)}
        </SelectContent>
      </Select>
    </div>
  );
}
