import type { ReactNode } from "react";
import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { Breadcrumb } from "@/components/shared/breadcrumb";
import { ProjectRoleProvider } from "@/components/workspace/project-role-provider";
import { WorkspaceTabs } from "@/app/(app)/workspaces/[id]/workspace-tabs";
import { getWorkspace } from "@/lib/workspace/server";
import ROUTES from "@/lib/routes";

interface LayoutProps {
  params: Promise<{ id: string }>;
  children: ReactNode;
}

export async function generateMetadata({ params }: LayoutProps): Promise<Metadata> {
  const { id } = await params;
  try {
    const workspace = await getWorkspace(id);
    return { title: workspace.title };
  } catch {
    return { title: "Workspace" };
  }
}

export default async function WorkspaceLayout({ params, children }: LayoutProps) {
  const { id } = await params;

  let workspace: Awaited<ReturnType<typeof getWorkspace>>;
  try {
    workspace = await getWorkspace(id);
  } catch {
    notFound();
  }

  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Workspaces", href: ROUTES.WORKSPACES }, { label: workspace.title }]} />

      <ProjectRoleProvider
        isOverseer={workspace.is_overseer}
        ledTrackIds={workspace.led_track_ids}
        myTrackIds={workspace.my_track_ids}
        role={workspace.my_role}
      >
        <WorkspaceTabs sprintsEnabled={workspace.sprints_enabled} workspaceId={id} />
        {children}
      </ProjectRoleProvider>
    </main>
  );
}
