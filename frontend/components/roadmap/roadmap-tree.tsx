import { ModuleRow } from "@/components/roadmap/module-row";
import type { Roadmap } from "@/lib/server/roadmap";

export function RoadmapTree({ roadmap, readOnly }: { roadmap: Roadmap; readOnly?: boolean }) {
  const phases = roadmap.phases ?? [];

  return (
    <ol aria-label="Roadmap phases" className="flex flex-col gap-8">
      {phases.map((phase, phaseIdx) => (
        <li key={phase.id}>
          <div className="mb-3 flex items-baseline gap-2">
            <span className="ai-badge">Phase {phaseIdx + 1}</span>
            <h2 className="section-title">{phase.title}</h2>
            {phase.estimated_weeks ? (
              <span className="text-sm text-muted-foreground">~{phase.estimated_weeks}w</span>
            ) : null}
          </div>
          {phase.description && <p className="mb-4 text-muted-foreground">{phase.description}</p>}

          <ol aria-label={`${phase.title} milestones`} className="flex flex-col gap-5 border-l border-border pl-5">
            {phase.milestones.map((milestone) => (
              <li key={milestone.id}>
                <div className="mb-2 flex items-baseline gap-2">
                  <h3 className="font-semibold">{milestone.title}</h3>
                  {milestone.estimated_hours ? (
                    <span className="text-xs text-muted-foreground">~{milestone.estimated_hours}h</span>
                  ) : null}
                </div>
                {milestone.description && (
                  <p className="mb-2 text-sm text-muted-foreground">{milestone.description}</p>
                )}
                <ul aria-label={`${milestone.title} modules`} className="flex flex-col gap-2">
                  {milestone.modules.map((mod) => (
                    <ModuleRow key={mod.id} mod={mod} readOnly={readOnly} roadmapId={roadmap.id} />
                  ))}
                </ul>
              </li>
            ))}
          </ol>
        </li>
      ))}
    </ol>
  );
}
