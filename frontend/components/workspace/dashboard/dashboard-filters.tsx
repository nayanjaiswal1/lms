"use client";

import { parseAsString, useQueryStates } from "nuqs";

import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { Member, Track } from "@/lib/workspace/types";

interface DashboardFiltersProps {
  tracks: Track[];
  members: Member[];
  showTrackFilter: boolean;
  showUserFilter: boolean;
}

/** URL-driven (frontend/CLAUDE.md) — from/to/track/user all live in the query
 * string so a link into the dashboard (e.g. from a digest email) can carry a
 * specific view. Visibility of the track/user pickers themselves is server-
 * resolved (D15: track leads only see their own track, members only
 * themselves) — this component just doesn't render controls the caller
 * can't use anyway. */
export function DashboardFilters({ tracks, members, showTrackFilter, showUserFilter }: DashboardFiltersProps) {
  const [filters, setFilters] = useQueryStates({
    from: parseAsString,
    to: parseAsString,
    track: parseAsString,
    user: parseAsString,
  });

  return (
    <div className="flex flex-wrap items-center gap-2">
      <Input
        aria-label="From date"
        className="w-full sm:w-[160px]"
        type="date"
        value={filters.from ?? ""}
        onChange={(e) => void setFilters({ from: e.target.value || null })}
      />
      <Input
        aria-label="To date"
        className="w-full sm:w-[160px]"
        type="date"
        value={filters.to ?? ""}
        onChange={(e) => void setFilters({ to: e.target.value || null })}
      />
      {showTrackFilter && (
        <Select value={filters.track ?? "all"} onValueChange={(v) => void setFilters({ track: v === "all" ? null : v })}>
          <SelectTrigger className="w-full sm:w-[160px]"><SelectValue placeholder="Track" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All tracks</SelectItem>
            {tracks.map((t) => <SelectItem key={t.id} value={t.id}>{t.name}</SelectItem>)}
          </SelectContent>
        </Select>
      )}
      {showUserFilter && (
        <Select value={filters.user ?? "all"} onValueChange={(v) => void setFilters({ user: v === "all" ? null : v })}>
          <SelectTrigger className="w-full sm:w-[170px]"><SelectValue placeholder="Person" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">Everyone</SelectItem>
            {members.map((m) => <SelectItem key={m.user_id} value={m.user_id}>{m.name}</SelectItem>)}
          </SelectContent>
        </Select>
      )}
    </div>
  );
}
