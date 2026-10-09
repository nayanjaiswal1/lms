import { Badge } from "@/components/ui/badge";
import { ApplyInterestPanel } from "@/components/workspace/apply-interest-panel";
import type { DiscoverWorkspace } from "@/lib/workspace/discover-types";

interface DiscoverListProps {
  workspaces: DiscoverWorkspace[];
}

export function DiscoverList({ workspaces }: DiscoverListProps) {
  return (
    <div className="card-grid">
      {workspaces.map((w) => (
        <article className="card-base flex flex-col gap-3 p-6" key={w.id}>
          <h2 className="text-base font-semibold">{w.title}</h2>
          <p className="line-clamp-3 text-sm text-muted-foreground">{w.summary}</p>
          {w.skills.length > 0 && (
            <div className="flex flex-wrap gap-1.5">
              {w.skills.map((skill) => (
                <Badge key={skill} variant="outline">
                  {skill}
                </Badge>
              ))}
            </div>
          )}
          <span className="text-xs text-muted-foreground">
            Team of {w.team_size_min}–{w.team_size_max}
            {w.interest_deadline && ` · closes ${new Date(w.interest_deadline).toLocaleDateString()}`}
          </span>
          <ApplyInterestPanel hasApplied={w.has_applied} workspaceId={w.id} />
        </article>
      ))}
    </div>
  );
}
