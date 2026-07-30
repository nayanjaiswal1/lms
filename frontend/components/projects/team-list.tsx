import { TeamCard } from "@/components/projects/team-card";
import type { ProjectTeam, ProjectTeamMember, TeamActivityView, TeamDashboardSummary } from "@/lib/projects/types";
import type { BatchMember } from "@/lib/server/batches";

interface TeamListProps {
  assignmentId: string;
  teams: ProjectTeam[];
  membersByTeam: Record<string, ProjectTeamMember[]>;
  activityByTeam: Record<string, TeamActivityView>;
  dashboardByTeam: Record<string, TeamDashboardSummary>;
  availableStudents: BatchMember[];
}

export function TeamList({ assignmentId, teams, membersByTeam, activityByTeam, dashboardByTeam, availableStudents }: TeamListProps) {
  if (teams.length === 0) {
    return (
      <p className="py-6 text-center text-sm text-muted-foreground">
        No teams yet. Create one to give students a repo to work in.
      </p>
    );
  }

  return (
    <section className="card-grid">
      {teams.map((team) => (
        <TeamCard
          activity={activityByTeam[team.id] ?? { commits: [], merge_requests: [], pipeline: null }}
          assignmentId={assignmentId}
          availableStudents={availableStudents}
          dashboard={dashboardByTeam[team.id]}
          key={team.id}
          members={membersByTeam[team.id] ?? []}
          team={team}
        />
      ))}
    </section>
  );
}
