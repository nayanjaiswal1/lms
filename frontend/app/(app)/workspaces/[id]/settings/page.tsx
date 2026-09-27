import type { Metadata } from "next";

import { ForbiddenSection } from "@/components/workspace/forbidden-section";
import { ProjectSettingsForm } from "@/components/workspace/project-settings-form";
import { getWorkspace, listWorkspaceMembers } from "@/lib/workspace/server";
import { isOwner } from "@/lib/workspace/roles";

export const metadata: Metadata = {
  title: "Workspace Settings",
};

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function WorkspaceSettingsPage({ params }: PageProps) {
  const { id } = await params;
  const workspace = await getWorkspace(id);
  if (!isOwner(workspace.my_role)) return <ForbiddenSection />;

  const members = await listWorkspaceMembers(id);

  return <ProjectSettingsForm members={members} project={workspace} workspaceId={id} />;
}
