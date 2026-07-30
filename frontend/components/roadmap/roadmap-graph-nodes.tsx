"use client";

import Link from "next/link";
import { Check, ExternalLink } from "lucide-react";
import { MODULE_ICON, resourceHref } from "@/components/roadmap/module-row";
import { ModuleProgressToggle } from "@/components/roadmap/module-progress-toggle";
import { cn } from "@/lib/utils";
import type { MilestoneBox, ModuleBox, PhaseBox } from "@/lib/roadmap/graph-layout";

export function PhaseBoxNode({ box }: { box: PhaseBox }) {
  return (
    <g>
      <rect
        className="fill-primary stroke-primary"
        height={box.height}
        rx={14}
        strokeWidth={2}
        width={box.width}
        x={box.x}
        y={box.y}
      />
      <foreignObject height={box.height} width={box.width} x={box.x} y={box.y}>
        <div className="flex h-full flex-col justify-center overflow-hidden px-3 text-primary-foreground">
          <p className="truncate text-sm font-semibold leading-tight">{box.phase.title}</p>
          {box.phase.estimated_weeks ? (
            <p className="text-xs opacity-80">~{box.phase.estimated_weeks}w</p>
          ) : null}
        </div>
      </foreignObject>
    </g>
  );
}

export function MilestoneBoxNode({ box }: { box: MilestoneBox }) {
  return (
    <g>
      <rect
        className="fill-ai/10 stroke-ai/50"
        height={box.height}
        rx={12}
        strokeDasharray="5 4"
        strokeWidth={2}
        width={box.width}
        x={box.x}
        y={box.y}
      />
      <foreignObject height={32} width={box.width} x={box.x} y={box.y}>
        <div className="flex h-full items-baseline gap-1.5 overflow-hidden px-3 pt-2">
          <p className="truncate text-sm font-semibold text-foreground">{box.milestone.title}</p>
          {box.milestone.estimated_hours ? (
            <span className="shrink-0 text-xs text-muted-foreground">~{box.milestone.estimated_hours}h</span>
          ) : null}
        </div>
      </foreignObject>
    </g>
  );
}

export function ModuleBoxNode({ box, roadmapId }: { box: ModuleBox; roadmapId: string }) {
  const mod = box.module;
  const Icon = MODULE_ICON[mod.module_type];
  const href = resourceHref(mod);
  const completed = Boolean(mod.completed_at);

  return (
    <foreignObject height={box.height} width={box.width} x={box.x} y={box.y}>
      <div
        className={cn(
          "card-base relative flex h-full w-full items-center gap-1.5 p-1.5",
          completed ? "border-success bg-success/10" : "border-2 border-foreground/20",
        )}
      >
        {completed && (
          <div className="absolute -right-2 -top-2 flex h-5 w-5 items-center justify-center rounded-full border-2 border-background bg-success">
            <Check aria-hidden className="h-3 w-3 text-success-foreground" />
          </div>
        )}
        <ModuleProgressToggle
          completed={completed}
          moduleId={mod.id}
          roadmapId={roadmapId}
          title={mod.title}
        />
        <Icon aria-hidden className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
        <div className="flex min-w-0 flex-1 flex-col">
          <span className={cn("truncate text-xs font-medium", completed && "text-muted-foreground line-through")}>
            {mod.title}
          </span>
          {mod.resource_title && href && (
            <Link className="flex w-fit items-center gap-1 truncate text-[10px] text-ai" href={href}>
              <ExternalLink aria-hidden className="h-2.5 w-2.5 shrink-0" />
              <span className="truncate">{mod.resource_title}</span>
            </Link>
          )}
        </div>
      </div>
    </foreignObject>
  );
}
