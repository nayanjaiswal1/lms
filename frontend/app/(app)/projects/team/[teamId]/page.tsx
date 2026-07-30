import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ExternalLink, FolderGit2 } from "lucide-react";

import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getMyProject, getMyProjectCheckpoints, getMyProjectContributions, listMyProjects } from "@/lib/projects/server";
import { PROVISION_STATUS_LABEL, PROVISION_VARIANT } from "@/lib/constants";
import { ContributionBreakdown } from "@/components/projects/contribution-breakdown";
import { MyCheckpointList } from "@/components/projects/my-checkpoint-list";
import { Badge } from "@/components/ui/badge";
import type { ProjectTeam } from "@/lib/projects/types";

export const metadata: Metadata = { title: "My Project" };

interface PageProps {
  params: Promise<{ teamId: string }>;
}

export default async function MyProjectDetailPage({ params }: PageProps) {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);
  const { teamId } = await params;

  // GetMyProject 404s (not 403) for a team the caller doesn't belong to, so
  // a non-member gets the same "not found" as a team that doesn't exist —
  // see the handler's own doc comment in handler_dashboard.go.
  let team: ProjectTeam;
  let myProjects: Awaited<ReturnType<typeof listMyProjects>>;
  try {
    [team, myProjects] = await Promise.all([getMyProject(teamId), listMyProjects()]);
  } catch {
    notFound();
  }

  const summary = myProjects.find((p) => p.team_id === teamId);
  const [contributions, checkpoints] = await Promise.all([getMyProjectContributions(teamId), getMyProjectCheckpoints(teamId)]);

  return (
    <main className="page-container">
      <header className="page-header items-start">
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-2">
            <h1 className="page-title">{team.name}</h1>
            <Badge variant={PROVISION_VARIANT[team.provision_status] ?? "outline"}>
              {PROVISION_STATUS_LABEL[team.provision_status] ?? team.provision_status}
            </Badge>
          </div>
          {summary && (
            <p className="text-muted-foreground">
              {summary.assignment_title} · <span className="capitalize">{summary.role}</span>
            </p>
          )}
        </div>
        <div className="flex shrink-0 flex-wrap gap-2">
          {team.gitlab_web_url && (
            <a
              className="inline-flex items-center gap-1.5 rounded-md border border-border px-3 py-2 text-sm hover:bg-muted"
              href={team.gitlab_web_url}
              rel="noreferrer"
              target="_blank"
            >
              <FolderGit2 aria-hidden className="h-4 w-4" />
              Repo <ExternalLink aria-hidden className="h-3.5 w-3.5" />
            </a>
          )}
          {team.pages_url && (
            <a
              className="inline-flex items-center gap-1.5 rounded-md border border-border px-3 py-2 text-sm hover:bg-muted"
              href={team.pages_url}
              rel="noreferrer"
              target="_blank"
            >
              Pages <ExternalLink aria-hidden className="h-3.5 w-3.5" />
            </a>
          )}
        </div>
      </header>

      {team.provision_status === "failed" && team.provision_error && (
        <p className="mb-4 text-sm text-destructive">{team.provision_error}</p>
      )}

      <section className="card-base mt-6 flex flex-col gap-4 p-6">
        <h2 className="section-title">Checkpoints</h2>
        <MyCheckpointList checkpoints={checkpoints.checkpoints} />
      </section>

      <section className="card-base mt-6 flex flex-col gap-4 p-6">
        <h2 className="section-title">Team contributions</h2>
        <ContributionBreakdown contributions={contributions.contributions} />
      </section>
    </main>
  );
}
