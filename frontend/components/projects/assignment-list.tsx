"use client";

import Link from "next/link";
import { parseAsStringLiteral, useQueryState } from "nuqs";

import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { ProjectAssignment } from "@/lib/projects/types";
import ROUTES from "@/lib/routes";

interface Props {
  assignments: ProjectAssignment[];
  batchNameById: Record<string, string>;
}

const STATUS_VARIANT: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  draft:    "outline",
  active:   "default",
  archived: "secondary",
};

const STATUS_FILTERS = ["all", "draft", "active", "archived"] as const;
const STATUS_FILTER_LABEL: Record<(typeof STATUS_FILTERS)[number], string> = {
  all:      "All statuses",
  draft:    "Draft",
  active:   "Active",
  archived: "Archived",
};

export function AssignmentList({ assignments, batchNameById }: Props) {
  const [status, setStatus] = useQueryState("status", parseAsStringLiteral(STATUS_FILTERS).withDefault("all"));

  const filtered = status === "all" ? assignments : assignments.filter((a) => a.status === status);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-3">
        <p className="text-sm text-muted-foreground">
          {filtered.length} assignment{filtered.length === 1 ? "" : "s"}
        </p>
        <Select value={status} onValueChange={(v) => void setStatus(v as (typeof STATUS_FILTERS)[number])}>
          <SelectTrigger aria-label="Filter by status" className="h-8 w-40">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {STATUS_FILTERS.map((f) => (
              <SelectItem key={f} value={f}>{STATUS_FILTER_LABEL[f]}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {filtered.length === 0 ? (
        <p className="py-6 text-center text-sm text-muted-foreground">No assignments match this filter.</p>
      ) : (
        <section className="card-grid">
          {filtered.map((a) => (
            <Link className="card-interactive flex flex-col gap-3 p-6" href={ROUTES.projectAssignment(a.id)} key={a.id}>
              <div className="flex items-start justify-between gap-2">
                <span className="text-base font-semibold">{a.title}</span>
                <Badge variant={STATUS_VARIANT[a.status] ?? "outline"}>{a.status}</Badge>
              </div>
              {a.description && <p className="line-clamp-2 text-sm text-muted-foreground">{a.description}</p>}
              <div className="mt-auto flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
                <span>{batchNameById[a.batch_id] ?? "Unknown batch"}</span>
                <span className="capitalize">{a.visibility}</span>
                <span>{a.required_approvals} approval{a.required_approvals === 1 ? "" : "s"}</span>
              </div>
            </Link>
          ))}
        </section>
      )}
    </div>
  );
}
