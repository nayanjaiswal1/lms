"use client";

import * as React from "react";
import Link from "next/link";
import { parseAsStringEnum, useQueryState } from "nuqs";

import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { REQUIREMENT_STATUS_LABEL, REQUIREMENT_STATUS_VARIANT } from "@/lib/constants";
import type { ProjectRequirement, RequirementStatus } from "@/lib/projects/types";
import ROUTES from "@/lib/routes";

interface RequirementListProps {
  requirements: ProjectRequirement[];
}

const FILTER_VALUES = ["all", "draft", "open", "closed", "archived"] as const;
type Filter = (typeof FILTER_VALUES)[number];

function daysUntil(iso: string): number {
  return Math.ceil((new Date(iso).getTime() - Date.now()) / 86_400_000);
}

export function RequirementList({ requirements }: RequirementListProps) {
  const [filter, setFilter] = useQueryState("status", parseAsStringEnum<Filter>([...FILTER_VALUES]).withDefault("all"));

  const counts = React.useMemo(() => {
    const out: Record<Filter, number> = { all: requirements.length, draft: 0, open: 0, closed: 0, archived: 0 };
    for (const req of requirements) out[req.status]++;
    return out;
  }, [requirements]);

  const visible = filter === "all" ? requirements : requirements.filter((r) => r.status === filter);

  return (
    <Tabs value={filter} onValueChange={(next) => void setFilter(next as Filter)}>
      <TabsList>
        {FILTER_VALUES.map((value) => (
          <TabsTrigger key={value} value={value}>
            {value === "all" ? "All" : (REQUIREMENT_STATUS_LABEL[value] ?? value)} ({counts[value]})
          </TabsTrigger>
        ))}
      </TabsList>

      <TabsContent className="mt-6" value={filter}>
        {visible.length === 0 ? (
          <div className="empty-state py-12">
            <p className="font-medium text-muted-foreground">
              {filter === "all" ? "No requirements yet." : `No ${REQUIREMENT_STATUS_LABEL[filter as RequirementStatus] ?? filter} requirements.`}
            </p>
          </div>
        ) : (
          <div className="card-grid">
            {visible.map((req) => {
              const daysLeft = req.status === "open" ? daysUntil(req.application_deadline) : null;
              return (
                <Link
                  className="card-base card-interactive flex flex-col gap-3 p-6"
                  href={ROUTES.projectRequirement(req.id)}
                  key={req.id}
                >
                  <div className="flex items-start justify-between gap-2">
                    <span className="text-base font-semibold">{req.title}</span>
                    <Badge variant={REQUIREMENT_STATUS_VARIANT[req.status] ?? "outline"}>
                      {REQUIREMENT_STATUS_LABEL[req.status] ?? req.status}
                    </Badge>
                  </div>
                  <p className="line-clamp-2 text-sm text-muted-foreground">{req.brief}</p>
                  <span className="text-xs text-muted-foreground">
                    Team of {req.team_size_min}–{req.team_size_max}
                    {daysLeft !== null && (
                      <>
                        {" · "}
                        <span className={daysLeft <= 2 ? "font-medium text-destructive" : undefined}>
                          {daysLeft <= 0 ? "closes today" : `${daysLeft} day${daysLeft === 1 ? "" : "s"} left`}
                        </span>
                      </>
                    )}
                  </span>
                </Link>
              );
            })}
          </div>
        )}
      </TabsContent>
    </Tabs>
  );
}
