"use client";

import Link from "next/link";
import { parseAsStringLiteral, useQueryState } from "nuqs";
import { BarChart3, Briefcase, GraduationCap } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { AssessmentSearchInput } from "@/app/(app)/assessments/assessment-search-input";
import { AssessmentCardMenu } from "@/app/(app)/assessments/assessment-card-menu";
import { ASSESSMENT_PARENT_TYPE, ASSESSMENT_STATUS_OPTIONS } from "@/lib/constants";
import type { Assessment, Batch } from "@/lib/assessments/types";
import ROUTES from "@/lib/routes";

interface Props {
  assessments: Assessment[];
  batches: Batch[];
}

const STATUS_VARIANT: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  draft: "outline",
  published: "default",
  scheduled: "secondary",
  active: "default",
  completed: "secondary",
  archived: "destructive",
};

const STATUS_FILTERS = ["all", ...ASSESSMENT_STATUS_OPTIONS.map((o) => o.value)] as const;
const STATUS_FILTER_LABEL: Record<string, string> = {
  all: "All statuses",
  ...Object.fromEntries(ASSESSMENT_STATUS_OPTIONS.map((o) => [o.value, o.label])),
};

const GROUP_MODES = ["course", "none"] as const;
const GROUP_MODE_LABEL: Record<(typeof GROUP_MODES)[number], string> = {
  course: "Group by course",
  none:   "Flat list",
};

const STANDALONE_GROUP = "__standalone";
const HIRING_GROUP = "__hiring";

export function AssessmentList({ assessments, batches }: Props) {
  const [status, setStatus] = useQueryState("status", parseAsStringLiteral(STATUS_FILTERS).withDefault("all"));
  const [group, setGroup] = useQueryState("group", parseAsStringLiteral(GROUP_MODES).withDefault("course"));

  const filtered = status === "all" ? assessments : assessments.filter((a) => a.status === status);

  const controls = (
    <div className="flex items-center gap-2 flex-wrap">
      <AssessmentSearchInput />
      <Select value={status} onValueChange={(v) => void setStatus(v as (typeof STATUS_FILTERS)[number])}>
        <SelectTrigger aria-label="Filter by status" className="h-8 w-36">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {STATUS_FILTERS.map((f) => (
            <SelectItem key={f} value={f}>{STATUS_FILTER_LABEL[f]}</SelectItem>
          ))}
        </SelectContent>
      </Select>
      <Select value={group} onValueChange={(v) => void setGroup(v as (typeof GROUP_MODES)[number])}>
        <SelectTrigger aria-label="Group by" className="h-8 w-44">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {GROUP_MODES.map((g) => (
            <SelectItem key={g} value={g}>{GROUP_MODE_LABEL[g]}</SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );

  const countLabel = `${filtered.length} assessment${filtered.length === 1 ? "" : "s"}`;

  if (filtered.length === 0) {
    return (
      <div className="flex flex-col gap-4">
        <div className="flex flex-col gap-3">
          <p className="text-sm text-muted-foreground">0 assessments</p>
          {controls}
        </div>
        <p className="py-6 text-center text-sm text-muted-foreground">No assessments match this filter.</p>
      </div>
    );
  }

  if (group === "none") {
    return (
      <div className="flex flex-col gap-4">
        <div className="flex flex-col gap-3">
          <p className="text-sm text-muted-foreground">{countLabel}</p>
          {controls}
        </div>
        <section className="card-grid">
          {filtered.map((a) => (
            <AssessmentCard assessment={a} batches={batches} key={a.id} />
          ))}
        </section>
      </div>
    );
  }

  const grouped = new Map<string, { label: string; items: Assessment[] }>();
  for (const a of filtered) {
    const key = a.course_id ?? (a.parent_type === ASSESSMENT_PARENT_TYPE.HIRING ? HIRING_GROUP : STANDALONE_GROUP);
    const label = a.course_title ?? (a.parent_type === ASSESSMENT_PARENT_TYPE.HIRING ? "Hiring / Recruitment" : "Standalone");
    const entry = grouped.get(key) ?? { label, items: [] };
    entry.items.push(a);
    grouped.set(key, entry);
  }
  const rank = (k: string) => (k === STANDALONE_GROUP ? 2 : k === HIRING_GROUP ? 1 : 0);
  const groups = [...grouped.entries()]
    .map(([key, entry]) => ({ key, ...entry }))
    .sort((a, b) => rank(a.key) - rank(b.key) || a.label.localeCompare(b.label));
  const groupKeys = groups.map((g) => g.key);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-3">
        <p className="text-sm text-muted-foreground">
          {countLabel} in {groupKeys.length} group{groupKeys.length === 1 ? "" : "s"}
        </p>
        {controls}
      </div>
      <Accordion defaultValue={groupKeys} type="multiple">
        {groups.map(({ key, label, items }) => {
          return (
            <AccordionItem key={key} value={key}>
              <AccordionTrigger>
                <span className="flex items-center gap-2 normal-case tracking-normal text-foreground">
                  {key !== STANDALONE_GROUP && key !== HIRING_GROUP && (
                    <GraduationCap aria-hidden className="h-4 w-4 text-primary" />
                  )}
                  {label}
                  <Badge variant="secondary">{items.length}</Badge>
                </span>
              </AccordionTrigger>
              <AccordionContent>
                <section className="card-grid">
                  {items.map((a) => (
                    <AssessmentCard assessment={a} batches={batches} key={a.id} />
                  ))}
                </section>
              </AccordionContent>
            </AccordionItem>
          );
        })}
      </Accordion>
    </div>
  );
}

function AssessmentCard({ assessment: a, batches }: { assessment: Assessment; batches: Batch[] }) {
  return (
    <article className="card-interactive flex flex-col gap-3 p-6">
      <div className="flex items-start justify-between gap-2">
        <Link className="text-base font-semibold hover:underline" href={ROUTES.assessmentEdit(a.id)}>
          {a.title}
        </Link>
        <div className="flex shrink-0 items-center gap-1.5">
          {a.parent_type === ASSESSMENT_PARENT_TYPE.HIRING && (
            <Badge variant="secondary">
              <Briefcase /> Hiring
            </Badge>
          )}
          <Badge variant={STATUS_VARIANT[a.status] ?? "outline"}>{a.status}</Badge>
          <AssessmentCardMenu assessment={a} batches={batches} />
        </div>
      </div>
      <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
        <span>{a.type}</span>
        <span>{a.question_count} questions</span>
        <span>{a.duration_minutes} min</span>
        <span>{a.total_points} pts</span>
      </div>
      <div className="mt-auto flex gap-2">
        <Button asChild size="sm" variant="outline">
          <Link href={ROUTES.assessmentEdit(a.id)}>Manage questions</Link>
        </Button>
        <Button asChild size="sm" variant="ghost">
          <Link href={ROUTES.assessmentResults(a.id)}>
            <BarChart3 /> Results
          </Link>
        </Button>
      </div>
    </article>
  );
}
