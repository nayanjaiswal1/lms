import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { Badge } from "@/components/ui/badge";
import { PublicInterestForm } from "@/components/workspace/public-interest-form";
import { getPublicWorkspace } from "@/lib/workspace/server";
import type { PublicClosedReason } from "@/lib/workspace/types";

interface PageProps {
  params: Promise<{ token: string }>;
}

const CLOSED_MESSAGE: Record<PublicClosedReason, string> = {
  deadline_passed: "The interest deadline for this project has passed.",
  seats_full: "This project's team is already full.",
  not_accepting: "This project isn't accepting interest right now.",
};

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { token } = await params;
  try {
    const project = await getPublicWorkspace(token);
    return { title: project.title, description: `Join ${project.org_name} on ${project.title}` };
  } catch {
    return { title: "Project" };
  }
}

export default async function JoinWorkspacePage({ params }: PageProps) {
  const { token } = await params;
  let project;
  try {
    project = await getPublicWorkspace(token);
  } catch {
    notFound();
  }

  return (
    // eslint-disable-next-line no-restricted-syntax -- standalone public page outside the (app) shell, no .app-content ancestor to supply vertical padding
    <main className="page-container-sm py-12">
      <div className="flex flex-col gap-6">
        <div className="flex flex-col gap-2">
          <p className="text-sm text-muted-foreground">{project.org_name}</p>
          <h1 className="page-title">{project.title}</h1>
          {project.skills.length > 0 && (
            <div className="flex flex-wrap gap-1.5">
              {project.skills.map((skill) => (
                <Badge key={skill} variant="secondary">{skill}</Badge>
              ))}
            </div>
          )}
        </div>

        <p className="prose-content whitespace-pre-wrap">{project.requirement}</p>

        <div className="grid grid-cols-2 gap-4 text-sm sm:grid-cols-3">
          <div>
            <p className="text-xs text-muted-foreground">Team size</p>
            <p className="font-medium">
              {project.team_size_min}–{project.team_size_max}
            </p>
          </div>
          <div>
            <p className="text-xs text-muted-foreground">Seats left</p>
            <p className="font-medium">{project.seats_left}</p>
          </div>
          {project.interest_deadline && (
            <div>
              <p className="text-xs text-muted-foreground">Deadline</p>
              <p className="font-medium">{new Date(project.interest_deadline).toLocaleDateString()}</p>
            </div>
          )}
        </div>

        <div className="card-base">
          {project.open ? (
            <PublicInterestForm shareToken={token} />
          ) : (
            <div className="empty-state">
              <p className="font-medium text-muted-foreground">
                {project.closed_reason ? CLOSED_MESSAGE[project.closed_reason] : "This project isn't accepting interest right now."}
              </p>
            </div>
          )}
        </div>
      </div>
    </main>
  );
}
