import type { Metadata } from "next";

import { TrackList } from "@/components/workspace/track-list";
import { getCurrentUser } from "@/lib/server/auth";
import { getWorkspace, listWorkspaceMembers, listWorkspaceTracks } from "@/lib/workspace/server";
import { canManage } from "@/lib/workspace/roles";
import type { ProjectStatus } from "@/lib/workspace/types";

export const metadata: Metadata = {
  title: "Tracks",
};

const PLANNING_STATUSES = new Set<ProjectStatus>(["draft", "recruiting", "active"]);

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function WorkspaceTracksPage({ params }: PageProps) {
  const { id } = await params;
  const [workspace, tracks, members, currentUser] = await Promise.all([
    getWorkspace(id),
    listWorkspaceTracks(id),
    listWorkspaceMembers(id),
    getCurrentUser(),
  ]);

  return (
    <TrackList
      canEditStructure={PLANNING_STATUSES.has(workspace.project_status)}
      canManage={canManage(workspace.my_role)}
      currentUserId={currentUser?.id ?? ""}
      ledTrackIds={workspace.led_track_ids}
      members={members}
      tracks={tracks}
      workspaceId={id}
    />
  );
}
