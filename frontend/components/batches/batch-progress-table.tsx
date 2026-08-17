"use client";

import { useMemo } from "react";
import { Users } from "lucide-react";
import { parseAsString, parseAsStringLiteral, useQueryState } from "nuqs";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { UserLink } from "@/components/shared/user-link";
import type { MemberProgress, MemberStatus } from "@/lib/server/batches";
import type { Terminology } from "@/lib/terminology";

interface BatchProgressTableProps {
  progress: MemberProgress[];
  t: Terminology;
}

const STATUS_FILTER_VALUES = ["all", "on_track", "needs_support", "not_engaged"] as const;
type StatusFilter = (typeof STATUS_FILTER_VALUES)[number];

const STATUS_BADGE: Record<MemberStatus, { label: string; variant: "default" | "secondary" | "destructive" }> = {
  on_track:      { label: "On track",      variant: "default" },
  needs_support: { label: "Needs support", variant: "secondary" },
  not_engaged:   { label: "Not engaged",   variant: "destructive" },
};

export function BatchProgressTable({ progress, t }: BatchProgressTableProps) {
  const [query, setQuery] = useQueryState("q", parseAsString.withDefault(""));
  const [status, setStatus] = useQueryState("status", parseAsStringLiteral(STATUS_FILTER_VALUES).withDefault("all"));

  const filterTabs: { value: StatusFilter; label: string }[] = [
    { value: "all", label: "All" },
    { value: "on_track", label: "On track" },
    { value: "needs_support", label: "Needs support" },
    { value: "not_engaged", label: "Not engaged" },
  ];

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return progress.filter((s) => {
      if (status !== "all" && s.status !== status) return false;
      if (q && !s.name.toLowerCase().includes(q) && !s.email.toLowerCase().includes(q)) return false;
      return true;
    });
  }, [progress, query, status]);

  if (progress.length === 0) {
    return (
      <div className="empty-state py-10">
        <Users aria-hidden className="h-8 w-8 text-muted-foreground" />
        <p className="mt-2 text-sm text-muted-foreground">No {t.studentPlural.toLowerCase()} enrolled yet.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-3">
        <Input
          className="w-full sm:w-64"
          placeholder={`Search ${t.studentPlural.toLowerCase()}…`}
          value={query}
          onChange={(e) => void setQuery(e.target.value || null)}
        />
        <div className="flex flex-wrap gap-1.5">
          {filterTabs.map((tab) => (
            <Button
              key={tab.value}
              size="sm"
              variant={status === tab.value ? "default" : "outline"}
              onClick={() => void setStatus(tab.value === "all" ? null : tab.value)}
            >
              {tab.label}
            </Button>
          ))}
        </div>
        <p className="ml-auto text-sm text-muted-foreground">
          {filtered.length} / {progress.length}
        </p>
      </div>

      {filtered.length === 0 ? (
        <p className="py-4 text-sm text-muted-foreground">No {t.studentPlural.toLowerCase()} match the current filters.</p>
      ) : (
        <div className="table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-xs text-muted-foreground">
                <th className="pb-2 font-medium">{t.student}</th>
                <th className="pb-2 pr-4 font-medium">Status</th>
                <th className="pb-2 pr-4 font-medium">Courses</th>
                <th className="pb-2 pr-4 font-medium">Tests passed</th>
                <th className="pb-2 pr-4 font-medium">Avg hints</th>
                <th className="pb-2 pr-4 font-medium">XP</th>
                <th className="pb-2 font-medium">Last active</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {filtered.map((s) => {
                const badge = STATUS_BADGE[s.status];
                return (
                  <tr key={s.user_id}>
                    <td className="py-2.5 pr-4">
                      <div className="flex flex-col">
                        <UserLink className="font-medium hover:underline" userId={s.user_id}>
                          {s.name}
                        </UserLink>
                        <span className="text-xs text-muted-foreground">{s.email}</span>
                      </div>
                    </td>
                    <td className="py-2.5 pr-4">
                      <Badge variant={badge.variant}>{badge.label}</Badge>
                    </td>
                    <td className="py-2.5 pr-4 tabular-nums">
                      {s.courses_completed}/{s.courses_enrolled}
                    </td>
                    <td className="py-2.5 pr-4 tabular-nums">{s.tests_passed}</td>
                    <td className="py-2.5 pr-4 tabular-nums">{s.avg_hints.toFixed(1)}</td>
                    <td className="py-2.5 pr-4 tabular-nums text-primary font-medium">{s.xp_total}</td>
                    <td className="py-2.5 text-muted-foreground">
                      {s.last_active_at ? new Date(s.last_active_at).toLocaleDateString() : "—"}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
