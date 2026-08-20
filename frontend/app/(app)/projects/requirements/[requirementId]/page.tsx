import type { Metadata } from "next";
import { Badge } from "@/components/ui/badge";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getProjectAssignments, getRequirement, listApplicationsForRequirement } from "@/lib/projects/server";
import { REQUIREMENT_STATUS_LABEL, REQUIREMENT_STATUS_VARIANT } from "@/lib/constants";
import { ApplicationReviewList } from "@/components/projects/application-review-list";
import { CreateTeamFromSelectionDialog } from "@/components/projects/create-team-from-selection-dialog";
import { PublishCloseRequirementButtons } from "@/components/projects/publish-close-requirement-buttons";
import { RunScoringButton } from "@/components/projects/run-scoring-button";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Project Requirement",
};

interface RequirementDetailPageProps {
  params: Promise<{ requirementId: string }>;
}

export default async function RequirementDetailPage({ params }: RequirementDetailPageProps) {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);
  const { requirementId } = await params;
  const [requirement, applications, assignments] = await Promise.all([
    getRequirement(requirementId),
    listApplicationsForRequirement(requirementId),
    getProjectAssignments(),
  ]);
  const unscoredCount = applications.filter((a) => a.ai_score === undefined).length;
  const selectedCount = applications.filter((a) => a.status === "selected").length;

  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Requirements", href: ROUTES.PROJECTS_REQUIREMENTS }, { label: requirement.title }]} />

      <header className="page-header">
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2">
            <h1 className="page-title">{requirement.title}</h1>
            <Badge variant={REQUIREMENT_STATUS_VARIANT[requirement.status] ?? "outline"}>
              {REQUIREMENT_STATUS_LABEL[requirement.status] ?? requirement.status}
            </Badge>
          </div>
          <p className="text-muted-foreground">
            Team of {requirement.team_size_min}–{requirement.team_size_max} · applications close{" "}
            {new Date(requirement.application_deadline).toLocaleString()}
          </p>
        </div>
        <PublishCloseRequirementButtons requirementId={requirement.id} status={requirement.status} />
      </header>

      <p className="prose-content mt-4 whitespace-pre-wrap">{requirement.brief}</p>

      {requirement.required_skills.length > 0 && (
        <div className="mt-4 flex flex-wrap gap-1.5">
          {requirement.required_skills.map((skill) => (
            <Badge key={skill} variant="outline">
              {skill}
            </Badge>
          ))}
        </div>
      )}

      <section className="mt-10">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
          <h2 className="section-title">Applications ({applications.length})</h2>
          <div className="flex flex-wrap gap-2">
            <RunScoringButton requirementId={requirement.id} unscoredCount={unscoredCount} />
            <CreateTeamFromSelectionDialog assignments={assignments} requirementId={requirement.id} selectedCount={selectedCount} />
          </div>
        </div>
        <ApplicationReviewList applications={applications} requirementId={requirement.id} />
      </section>
    </main>
  );
}
