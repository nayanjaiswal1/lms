import { ContributionBreakdown } from "@/components/workspace/gitlab/contribution-breakdown";
import { OwnershipTable } from "@/components/workspace/gitlab/ownership-table";
import { TeamActivityFeed } from "@/components/workspace/gitlab/team-activity-feed";
import { getWorkspaceContributions, getWorkspaceGitlabActivity, getWorkspaceOwnership } from "@/lib/workspace/gitlab-server";

interface WorkspaceGitlabSectionProps {
  workspaceId: string;
  workspaceTitle: string;
}

// The backend answers 409 when the caller has no GitLab team in this
// workspace; allSettled turns that (or any failure) into a quiet message
// instead of taking the whole dashboard down.
export async function WorkspaceGitlabSection({ workspaceId, workspaceTitle }: WorkspaceGitlabSectionProps) {
  const [contributions, ownership, activity] = await Promise.allSettled([
    getWorkspaceContributions(workspaceId),
    getWorkspaceOwnership(workspaceId),
    getWorkspaceGitlabActivity(workspaceId),
  ]);

  if (contributions.status === "rejected" && ownership.status === "rejected" && activity.status === "rejected") {
    return (
      <section className="card-base flex flex-col gap-2 p-6">
        <h2 className="section-title">GitLab</h2>
        <p className="text-sm text-muted-foreground">GitLab activity is unavailable — you are not on a team in this workspace yet.</p>
      </section>
    );
  }

  return (
    <>
      {contributions.status === "fulfilled" && (
        <section className="card-base flex flex-col gap-4 p-6">
          <div className="flex items-center justify-between gap-2">
            <h2 className="section-title">Team contributions</h2>
            {activity.status === "fulfilled" && (
              <TeamActivityFeed activity={activity.value} teamId={workspaceId} teamName={workspaceTitle} />
            )}
          </div>
          <ContributionBreakdown contributions={contributions.value.contributions} />
        </section>
      )}
      {ownership.status === "fulfilled" && (
        <section className="card-base flex flex-col gap-4 p-6">
          <h2 className="section-title">File ownership</h2>
          <OwnershipTable files={ownership.value.files} />
        </section>
      )}
    </>
  );
}
