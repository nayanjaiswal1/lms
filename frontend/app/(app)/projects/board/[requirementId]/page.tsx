import type { Metadata } from "next";
import { Badge } from "@/components/ui/badge";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getBoardRequirement, listMyApplications } from "@/lib/projects/server";
import { ApplyPanel } from "@/components/projects/apply-panel";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Project Requirement",
};

interface BoardRequirementPageProps {
  params: Promise<{ requirementId: string }>;
}

export default async function BoardRequirementPage({ params }: BoardRequirementPageProps) {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);
  const { requirementId } = await params;
  const [requirement, myApplications] = await Promise.all([
    getBoardRequirement(requirementId),
    listMyApplications(),
  ]);
  const myApplication = myApplications.find((a) => a.requirement_id === requirementId) ?? null;
  const daysLeft = Math.ceil((new Date(requirement.application_deadline).getTime() - Date.now()) / 86_400_000);
  const isUrgent = requirement.status === "open" && !myApplication && daysLeft <= 2;

  return (
    <main className="page-container-sm">
      <Breadcrumb items={[{ label: "Board", href: ROUTES.PROJECTS_BOARD }, { label: requirement.title }]} />

      <header className="mb-4 flex flex-col gap-2">
        <div className="flex flex-wrap items-center gap-2">
          <h1 className="page-title">{requirement.title}</h1>
          {isUrgent && (
            <Badge variant="destructive">{daysLeft <= 0 ? "Closes today" : `${daysLeft} day${daysLeft === 1 ? "" : "s"} left`}</Badge>
          )}
        </div>
        <p className="text-muted-foreground">
          Team of {requirement.team_size_min}–{requirement.team_size_max} · applications close{" "}
          {new Date(requirement.application_deadline).toLocaleString()}
        </p>
      </header>

      <p className="prose-content whitespace-pre-wrap">{requirement.brief}</p>

      {requirement.required_skills.length > 0 && (
        <div className="mt-4 flex flex-wrap gap-1.5">
          {requirement.required_skills.map((skill) => (
            <Badge key={skill} variant="outline">
              {skill}
            </Badge>
          ))}
        </div>
      )}

      <div className="mt-8">
        <ApplyPanel isOpen={requirement.status === "open"} myApplication={myApplication} requirementId={requirement.id} />
      </div>
    </main>
  );
}
