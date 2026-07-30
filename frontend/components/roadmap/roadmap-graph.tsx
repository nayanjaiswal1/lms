"use client";

import { useMemo } from "react";
import { MilestoneBoxNode, ModuleBoxNode, PhaseBoxNode } from "@/components/roadmap/roadmap-graph-nodes";
import { buildRoadmapLayout } from "@/lib/roadmap/graph-layout";
import type { RoadmapPhase } from "@/lib/server/roadmap";

interface RoadmapGraphProps {
  phases: RoadmapPhase[];
  roadmapId: string;
}

export function RoadmapGraph({ phases, roadmapId }: RoadmapGraphProps) {
  const layout = useMemo(() => buildRoadmapLayout(phases), [phases]);

  return (
    <div className="h-[650px] w-full overflow-auto rounded-lg border border-border bg-muted/20">
      <svg height={layout.height} width={layout.width}>
        {layout.connectors.map((connector) => (
          <path
            className="fill-none stroke-border"
            d={connector.path}
            key={connector.id}
            strokeDasharray="4 4"
            strokeWidth={2}
          />
        ))}
        {layout.phases.map((phaseBox) => (
          <g key={phaseBox.phase.id}>
            <PhaseBoxNode box={phaseBox} />
            {phaseBox.milestones.map((milestoneBox) => (
              <g key={milestoneBox.milestone.id}>
                <MilestoneBoxNode box={milestoneBox} />
                {milestoneBox.modules.map((moduleBox) => (
                  <ModuleBoxNode box={moduleBox} key={moduleBox.module.id} roadmapId={roadmapId} />
                ))}
              </g>
            ))}
          </g>
        ))}
      </svg>
    </div>
  );
}
