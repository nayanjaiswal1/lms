import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ExternalLink, FolderGit2 } from "lucide-react";

import ROUTES from "@/lib/routes";
import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getMyProjectDetail } from "@/lib/projects/server";
import { PROVISION_STATUS_LABEL, PROVISION_VARIANT } from "@/lib/constants";
import { ContributionBreakdown } from "@/components/projects/contribution-breakdown";
import { MyCheckpointList } from "@/components/projects/my-checkpoint-list";
import { Badge } from "@/components/ui/badge";
import { Breadcrumb } from "@/components/shared/breadcrumb";

export const metadata: Metadata = { title: "My Project" };

interface PageProps {
  params: Promise<{ teamId: string }>;
}

export default async function MyProjectDetailPage({ params }: PageProps) {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);
  const { teamId } = await params;

  // GetMyProjectDetail 404s (not 403) for a team the caller doesn't belong
  // to, so a non-member gets the same "not found" as a team that doesn't
  // exist — see the handler's own doc comment in handler_my_project.go.
  let team: Awaited<ReturnType<typeof getMyProjectDetail>>;
  try {
    team = await getMyProjectDetail(teamId);
  } catch {
    notFound();
  }

  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Projects", href: ROUTES.PROJECTS }, { label: team.name }]} />
      <header className="page-header items-start">
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-2">
            <h1 className="section-title">{team.name}</h1>
            <Badge variant={PROVISION_VARIANT[team.provision_status] ?? "outline"}>
              {PROVISION_STATUS_LABEL[team.provision_status] ?? team.provision_status}
            </Badge>
          </div>
          <p className="text-muted-foreground">
            {team.assignment_title} · <span className="capitalize">{team.role}</span>
          </p>
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
        <MyCheckpointList checkpoints={team.checkpoints} />
      </section>

      <section className="card-base mt-6 flex flex-col gap-4 p-6">
        <h2 className="section-title">Team contributions</h2>
        <ContributionBreakdown contributions={team.contributions} />
      </section>
    </main>
  );
}
