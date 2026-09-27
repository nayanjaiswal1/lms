import type { Metadata } from "next";

import { CreateReleaseDialog } from "@/components/workspace/releases/create-release-dialog";
import { ReleaseCard } from "@/components/workspace/releases/release-card";
import { listWorkspaceReleases } from "@/lib/workspace/phase5-server";
import { getWorkspace } from "@/lib/workspace/server";
import { roleAtLeast } from "@/lib/workspace/roles";

export const metadata: Metadata = {
  title: "Releases",
};

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function WorkspaceReleasesPage({ params }: PageProps) {
  const { id } = await params;
  const [workspace, releases] = await Promise.all([getWorkspace(id), listWorkspaceReleases(id)]);
  const canManage = roleAtLeast(workspace.my_role, "manager");

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="page-title">Releases</h1>
        {canManage && <CreateReleaseDialog workspaceId={id} />}
      </div>

      {releases.length === 0 && <p className="text-sm text-muted-foreground">No releases yet.</p>}

      <div className="flex flex-col gap-3">
        {releases.map((r) => (
          <ReleaseCard canManage={canManage} key={r.id} release={r} workspaceId={id} />
        ))}
      </div>
    </div>
  );
}
