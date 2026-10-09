import type { Metadata } from "next";

import { ForbiddenSection } from "@/components/workspace/forbidden-section";
import { ProjectSettingsForm } from "@/components/workspace/project-settings-form";
import { apiGet } from "@/lib/server/api";
import { getWorkspace, listWorkspaceMembers } from "@/lib/workspace/server";
import type { GitlabInstallationOption } from "@/lib/workspace/types";
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

  // Installations are best-effort: the picker is omitted if the list is unavailable.
  const [members, installations] = await Promise.all([
    listWorkspaceMembers(id),
    workspace.gitlab_enabled ? apiGet<GitlabInstallationOption[]>("/api/gitlab/installations").catch(() => []) : [],
  ]);

  return <ProjectSettingsForm installations={installations} members={members} project={workspace} workspaceId={id} />;
}
