import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ExternalLink, FolderGit2 } from "lucide-react";

import ROUTES from "@/lib/routes";
import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getMyProjectDetail, getMyProjectOwnership, listTasksForTeam } from "@/lib/projects/server";
import { ContributionBreakdown } from "@/components/projects/contribution-breakdown";
import { MyCheckpointList } from "@/components/projects/my-checkpoint-list";
import { OwnershipTable } from "@/components/projects/ownership-table";
import { Breadcrumb } from "@/components/shared/breadcrumb";

export const metadata: Metadata = { title: "Project Showcase" };

interface PageProps {
  params: Promise<{ teamId: string }>;
}

export default async function TeamShowcasePage({ params }: PageProps) {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);
  const { teamId } = await params;

  let team: Awaited<ReturnType<typeof getMyProjectDetail>>;
  try {
    team = await getMyProjectDetail(teamId);
  } catch {
    notFound();
  }
  const [ownership, tasks] = await Promise.all([getMyProjectOwnership(teamId), listTasksForTeam(teamId)]);

  const gradedCheckpoints = team.checkpoints.filter((cp) => cp.status === "graded");
  const avgScore =
    gradedCheckpoints.length > 0
      ? Math.round(gradedCheckpoints.reduce((sum, cp) => sum + (cp.score ?? 0), 0) / gradedCheckpoints.length)
      : null;
  const totalCommits = team.contributions.reduce((sum, c) => sum + c.commit_count, 0);
  const tasksDone = tasks.filter((t) => t.status === "done").length;

  return (
    <main className="page-container-sm">
      <Breadcrumb items={[{ label: "Projects", href: ROUTES.PROJECTS }, { label: team.name, href: ROUTES.myProject(teamId) }, { label: "Showcase" }]} />

      <header className="mb-6 flex flex-col gap-2">
        <h1 className="page-title">{team.name}</h1>
        <p className="text-muted-foreground">{team.assignment_title}</p>
        <div className="flex flex-wrap gap-2">
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
              Live site <ExternalLink aria-hidden className="h-3.5 w-3.5" />
            </a>
          )}
        </div>
      </header>

      <div className="grid-stats mb-8 grid gap-4">
        <div className="card-base p-4">
          <p className="text-xs text-muted-foreground">Checkpoints graded</p>
          <p className="text-2xl font-semibold">
            {gradedCheckpoints.length}/{team.checkpoints.length}
          </p>
        </div>
        <div className="card-base p-4">
          <p className="text-xs text-muted-foreground">Average score</p>
          <p className="text-2xl font-semibold">{avgScore !== null ? `${avgScore}/100` : "—"}</p>
        </div>
        <div className="card-base p-4">
          <p className="text-xs text-muted-foreground">Commits</p>
          <p className="text-2xl font-semibold">{totalCommits}</p>
        </div>
        <div className="card-base p-4">
          <p className="text-xs text-muted-foreground">Tasks completed</p>
          <p className="text-2xl font-semibold">
            {tasksDone}/{tasks.length}
          </p>
        </div>
      </div>

      <section className="card-base mb-6 flex flex-col gap-4 p-6">
        <h2 className="section-title">Checkpoints</h2>
        <MyCheckpointList checkpoints={team.checkpoints} requiredApprovals={team.required_approvals} />
      </section>

      <section className="card-base mb-6 flex flex-col gap-4 p-6">
        <h2 className="section-title">Contributions</h2>
        <ContributionBreakdown contributions={team.contributions} />
      </section>

      <section className="card-base flex flex-col gap-4 p-6">
        <h2 className="section-title">Code ownership</h2>
        <OwnershipTable files={ownership.files} />
      </section>
    </main>
  );
}
