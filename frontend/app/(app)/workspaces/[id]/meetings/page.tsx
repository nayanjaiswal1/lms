import type { Metadata } from "next";

import { MeetingList } from "@/components/workspace/meetings/meeting-list";
import { ScheduleMeetingDialog } from "@/components/workspace/meetings/schedule-meeting-dialog";
import { StandupsPanel } from "@/components/workspace/meetings/standups-panel";
import { getCurrentUser } from "@/lib/server/auth";
import { listWorkspaceMeetings, listWorkspaceStandups } from "@/lib/workspace/phase3-server";
import { roleAtLeast } from "@/lib/workspace/roles";
import { getWorkspace, listWorkspaceMembers } from "@/lib/workspace/server";

export const metadata: Metadata = {
  title: "Meetings",
};

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function WorkspaceMeetingsPage({ params }: PageProps) {
  const { id } = await params;
  const [workspace, meetingsPage, standups, members, currentUser] = await Promise.all([
    getWorkspace(id),
    listWorkspaceMeetings(id, undefined, 20),
    listWorkspaceStandups(id),
    listWorkspaceMembers(id),
    getCurrentUser(),
  ]);

  return (
    <div className="flex flex-col gap-8">
      <div className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h2 className="subsection-title">Meetings</h2>
          {roleAtLeast(workspace.my_role, "manager") && <ScheduleMeetingDialog members={members} workspaceId={id} />}
        </div>
        <MeetingList initialPage={meetingsPage} members={members} wikiSpaceSlug={workspace.wiki_space_slug} workspaceId={id} />
      </div>

      <StandupsPanel currentUserId={currentUser?.id ?? ""} initialStandups={standups} workspaceId={id} />
    </div>
  );
}
