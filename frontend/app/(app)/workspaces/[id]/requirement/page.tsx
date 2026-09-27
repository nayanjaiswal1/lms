import type { Metadata } from "next";

import { GapsPanel } from "@/components/workspace/clarify/gaps-panel";
import { QuestionThread } from "@/components/workspace/clarify/question-thread";
import { RequirementView } from "@/components/workspace/requirement-view";
import { getWorkspace, getWorkspaceRequirement } from "@/lib/workspace/server";
import { listWorkspaceQuestions } from "@/lib/workspace/phase3-server";
import { isOwner, roleAtLeast } from "@/lib/workspace/roles";
import type { ProjectStatus } from "@/lib/workspace/types";

export const metadata: Metadata = {
  title: "Requirement",
};

const PLANNING_STATUSES = new Set<ProjectStatus>(["draft", "recruiting", "active"]);

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function WorkspaceRequirementPage({ params }: PageProps) {
  const { id } = await params;
  const [workspace, requirement, questions] = await Promise.all([
    getWorkspace(id),
    getWorkspaceRequirement(id),
    listWorkspaceQuestions(id, undefined, 20),
  ]);

  return (
    <div className="flex flex-col gap-8">
      <RequirementView
        canEdit={isOwner(workspace.my_role) && PLANNING_STATUSES.has(workspace.project_status)}
        requirement={requirement}
        workspaceId={id}
      />

      {roleAtLeast(workspace.my_role, "manager") && <GapsPanel workspaceId={id} />}

      <div className="flex flex-col gap-3">
        <h2 className="subsection-title">Questions</h2>
        <QuestionThread initialPage={questions} workspaceId={id} />
      </div>
    </div>
  );
}
