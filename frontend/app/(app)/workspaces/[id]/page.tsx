import { notFound } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { ShowcaseStatsCard } from "@/components/workspace/gitlab/showcase-stats-card";
import { ProjectStatusMenu } from "@/components/workspace/project-status-menu";
import { getWorkspace } from "@/lib/workspace/server";
import { BRIEF_STATUS_LABEL } from "@/lib/workspace/roles";

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function WorkspaceHomePage({ params }: PageProps) {
  const { id } = await params;

  let workspace: Awaited<ReturnType<typeof getWorkspace>>;
  try {
    workspace = await getWorkspace(id);
  } catch {
    notFound();
  }

  const isOwner = workspace.my_role === "owner";
  const joinUrl = workspace.share_token ? `/join/${workspace.share_token}` : null;

  return (
    <div className="flex flex-col gap-6">
      <div className="page-header items-start">
        <div className="flex flex-col gap-2">
          <div className="flex flex-wrap items-center gap-2">
            <h1 className="section-title">{workspace.title}</h1>
            <Badge variant="outline">{workspace.key_prefix}</Badge>
          </div>
          {workspace.skills.length > 0 && (
            <div className="flex flex-wrap gap-1.5">
              {workspace.skills.map((skill) => (
                <Badge key={skill} variant="secondary">{skill}</Badge>
              ))}
            </div>
          )}
        </div>
        <ProjectStatusMenu canChange={isOwner} status={workspace.project_status} workspaceId={id} />
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div className="card-base">
          <p className="text-xs text-muted-foreground">Brief status</p>
          <p className="mt-1 text-lg font-semibold">{BRIEF_STATUS_LABEL[workspace.brief_status]}</p>
        </div>
        <div className="card-base">
          <p className="text-xs text-muted-foreground">Seats</p>
          <p className="mt-1 text-lg font-semibold">
            {workspace.seats_used} / {workspace.team_size_max}
          </p>
          <p className="text-xs text-muted-foreground">Min team size {workspace.team_size_min}</p>
        </div>
        <div className="card-base">
          <p className="text-xs text-muted-foreground">Interest deadline</p>
          <p className="mt-1 text-lg font-semibold">
            {workspace.interest_deadline ? new Date(workspace.interest_deadline).toLocaleDateString() : "None"}
          </p>
        </div>
        <div className="card-base">
          <p className="text-xs text-muted-foreground">Onboarding</p>
          <p className="mt-1 text-lg font-semibold">{workspace.onboarding_done ? "Complete" : "In progress"}</p>
        </div>
      </div>

      {workspace.team_id && <ShowcaseStatsCard workspaceId={id} />}

      {isOwner && (
        <div className="card-base flex flex-col gap-2">
          <h2 className="subsection-title">Share link</h2>
          <p className="break-all font-mono text-xs text-muted-foreground">
            {joinUrl ?? "No active link — open Settings to generate one."}
          </p>
        </div>
      )}

      <div className="card-base">
        <h2 className="subsection-title mb-2">Requirement</h2>
        <p className="prose-content line-clamp-4 whitespace-pre-wrap text-sm text-muted-foreground">{workspace.requirement}</p>
      </div>
    </div>
  );
}
