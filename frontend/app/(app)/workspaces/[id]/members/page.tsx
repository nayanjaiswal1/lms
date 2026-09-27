import type { Metadata } from "next";

import { MemberList } from "@/components/workspace/member-list";
import { LeaderlessTracksBanner } from "@/components/workspace/members/leaderless-tracks-banner";
import { getCurrentUser } from "@/lib/server/auth";
import { getWorkspace, listWorkspaceMembers, listWorkspaceTracks } from "@/lib/workspace/server";
import { canManage, isOwner } from "@/lib/workspace/roles";
import type { ProjectStatus } from "@/lib/workspace/types";

export const metadata: Metadata = {
  title: "Members",
};

const PLANNING_STATUSES = new Set<ProjectStatus>(["draft", "recruiting", "active"]);

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function WorkspaceMembersPage({ params }: PageProps) {
  const { id } = await params;
  const [workspace, members, tracks, currentUser] = await Promise.all([
    getWorkspace(id),
    listWorkspaceMembers(id),
    listWorkspaceTracks(id),
    getCurrentUser(),
  ]);

  return (
    <div className="flex flex-col gap-4">
      <LeaderlessTracksBanner tracks={tracks} workspaceId={id} />
      <MemberList
        canEditStructure={PLANNING_STATUSES.has(workspace.project_status)}
        canManage={canManage(workspace.my_role)}
        currentUserId={currentUser?.id ?? ""}
        isOwner={isOwner(workspace.my_role)}
        members={members}
        workspaceId={id}
      />
    </div>
  );
}
