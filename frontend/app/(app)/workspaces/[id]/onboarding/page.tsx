import type { Metadata } from "next";

import { OnboardingChecklist } from "@/components/workspace/onboarding-checklist";
import { getWorkspace, listWorkspaceOnboarding } from "@/lib/workspace/server";
import { canManage, roleAtLeast } from "@/lib/workspace/roles";

export const metadata: Metadata = {
  title: "Onboarding",
};

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function WorkspaceOnboardingPage({ params }: PageProps) {
  const { id } = await params;
  const [workspace, steps] = await Promise.all([getWorkspace(id), listWorkspaceOnboarding(id)]);

  return (
    <OnboardingChecklist
      canComplete={roleAtLeast(workspace.my_role, "member")}
      canManage={canManage(workspace.my_role)}
      steps={steps}
      workspaceId={id}
    />
  );
}
