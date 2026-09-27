import type { Metadata } from "next";

import { CreateItemDialog } from "@/components/workspace/items/create-item-dialog";
import { ItemBoard } from "@/components/workspace/items/item-board";
import { ItemFilters } from "@/components/workspace/items/item-filters";
import { SuggestEpicsButton } from "@/components/workspace/items/suggest-epics-button";
import { listWorkItems } from "@/lib/workspace/items-server";
import { roleAtLeast } from "@/lib/workspace/roles";
import { getWorkspace, listWorkspaceMembers, listWorkspaceTracks } from "@/lib/workspace/server";
import type { ItemType } from "@/lib/workspace/types";

export const metadata: Metadata = {
  title: "Backlog board",
};

const BOARD_TYPES: ItemType[] = ["task", "bug", "subtask"];

interface PageProps {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ type?: string; track?: string; assignee?: string; q?: string }>;
}

export default async function WorkspaceBoardPage({ params, searchParams }: PageProps) {
  const { id } = await params;
  const sp = await searchParams;
  const typeFilter = sp.type && BOARD_TYPES.includes(sp.type as ItemType) ? [sp.type as ItemType] : BOARD_TYPES;

  const [workspace, tracks, members, page] = await Promise.all([
    getWorkspace(id),
    listWorkspaceTracks(id),
    listWorkspaceMembers(id),
    listWorkItems(id, { type: typeFilter, track: sp.track, assignee: sp.assignee, q: sp.q, limit: 200 }),
  ]);

  const allowedTypes: ItemType[] = [];
  if (roleAtLeast(workspace.my_role, "manager")) allowedTypes.push("epic", "feature");
  else if (workspace.led_track_ids.length > 0) allowedTypes.push("feature");
  if (workspace.my_role !== "viewer") allowedTypes.push("task", "bug", "subtask");

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <ItemFilters members={members} showStatus={false} tracks={tracks} />
        <div className="flex gap-2">
          {roleAtLeast(workspace.my_role, "manager") && workspace.brief_status === "agreed" && (
            <SuggestEpicsButton tracks={tracks} workspaceId={id} />
          )}
          {allowedTypes.length > 0 && <CreateItemDialog allowedTypes={allowedTypes} tracks={tracks} workspaceId={id} />}
        </div>
      </div>
      <ItemBoard items={page.items} wipLimit={workspace.wip_limit} workspaceId={id} />
    </div>
  );
}
