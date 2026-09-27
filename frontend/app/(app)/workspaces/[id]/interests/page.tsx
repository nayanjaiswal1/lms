import type { Metadata } from "next";

import { ForbiddenSection } from "@/components/workspace/forbidden-section";
import { InterestReviewList } from "@/components/workspace/interest-review-list";
import { getWorkspace, listWorkspaceInterests } from "@/lib/workspace/server";
import { roleAtLeast } from "@/lib/workspace/roles";
import type { InterestStatus } from "@/lib/workspace/types";

export const metadata: Metadata = {
  title: "Interests",
};

interface PageProps {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ status?: string }>;
}

const VALID_STATUSES = new Set<InterestStatus>(["new", "accepted", "rejected", "invite_expired", "joined"]);

export default async function WorkspaceInterestsPage({ params, searchParams }: PageProps) {
  const { id } = await params;
  const sp = await searchParams;
  const status: InterestStatus = sp.status && VALID_STATUSES.has(sp.status as InterestStatus) ? (sp.status as InterestStatus) : "new";

  const workspace = await getWorkspace(id);
  if (!roleAtLeast(workspace.my_role, "manager")) return <ForbiddenSection />;

  const page = await listWorkspaceInterests(id, status, undefined, 20);
  const joinUrl = workspace.share_token ? `/join/${workspace.share_token}` : undefined;

  return (
    <InterestReviewList
      initialPage={page}
      joinUrl={joinUrl}
      key={status}
      seatsUsed={workspace.seats_used}
      status={status}
      teamSizeMax={workspace.team_size_max}
      workspaceId={id}
    />
  );
}
