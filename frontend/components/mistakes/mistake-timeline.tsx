"use client";

import { parseAsStringLiteral, useQueryState } from "nuqs";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { MISTAKE_CATEGORY_OPTIONS, MISTAKE_STATUS_LABEL } from "@/lib/constants";
import type { MistakeEntry } from "@/lib/server/mistakes";
import { MistakeResolveButton } from "@/components/mistakes/mistake-resolve-button";

const CATEGORY_FILTERS = ["all", ...MISTAKE_CATEGORY_OPTIONS.map((o) => o.value)] as const;
const CATEGORY_LABEL: Record<string, string> = Object.fromEntries(
  MISTAKE_CATEGORY_OPTIONS.map((o) => [o.value, o.label]),
);

const STATUS_BADGE_CLASS: Record<MistakeEntry["status"], string> = {
  new: "badge-muted",
  recurring: "badge-warning",
  improving: "badge-success",
  resolved: "badge-success",
};

interface MistakeTimelineProps {
  entries: MistakeEntry[];
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

function MistakeCard({ entry }: { entry: MistakeEntry }) {
  return (
    <article className="card-base flex flex-col gap-3 p-5">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div className="flex items-center gap-2 flex-wrap">
          <Badge variant="outline">{CATEGORY_LABEL[entry.category] ?? entry.category}</Badge>
          <Badge className={STATUS_BADGE_CLASS[entry.status]} variant="outline">
            {MISTAKE_STATUS_LABEL[entry.status]}
          </Badge>
          {entry.context_tag && (
            <span className="text-xs text-muted-foreground">{entry.context_tag}</span>
          )}
        </div>
        <time className="text-xs text-muted-foreground" dateTime={entry.created_at}>
          {formatDate(entry.created_at)}
        </time>
      </div>

      <p className="text-sm font-medium text-foreground">{entry.sub_topic}</p>

      <div className="flex flex-col gap-2 sm:flex-row sm:gap-4">
        <div className="flex-1 rounded-lg border border-destructive/30 bg-destructive/5 p-3">
          <p className="mb-1 text-xs font-medium text-destructive">You wrote</p>
          <p className="text-sm text-foreground">{entry.original_text}</p>
        </div>
        <div className="flex-1 rounded-lg border border-success/30 bg-success/5 p-3">
          <p className="mb-1 text-xs font-medium text-success">Correction</p>
          <p className="text-sm text-foreground">{entry.corrected_text}</p>
        </div>
      </div>

      {entry.status !== "resolved" && (
        <div className="flex justify-end">
          <MistakeResolveButton entryId={entry.id} />
        </div>
      )}
    </article>
  );
}

export function MistakeTimeline({ entries }: MistakeTimelineProps) {
  const [category, setCategory] = useQueryState(
    "category",
    parseAsStringLiteral(CATEGORY_FILTERS).withDefault("all"),
  );

  const filtered = category === "all" ? entries : entries.filter((e) => e.category === category);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <p className="text-sm text-muted-foreground">
          {filtered.length} mistake{filtered.length !== 1 ? "s" : ""}
        </p>
        <Select value={category} onValueChange={(v) => void setCategory(v as (typeof CATEGORY_FILTERS)[number])}>
          <SelectTrigger aria-label="Filter by category" className="h-8 w-48">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All categories</SelectItem>
            {MISTAKE_CATEGORY_OPTIONS.map((o) => (
              <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {filtered.length === 0 ? (
        <div className="empty-state py-16">
          <p className="text-center text-muted-foreground">
            No mistakes logged in this category yet.
          </p>
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {filtered.map((entry) => (
            <MistakeCard entry={entry} key={entry.id} />
          ))}
        </div>
      )}
    </div>
  );
}
