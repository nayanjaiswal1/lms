import type { Metadata } from "next";

import { CreateItemDialog } from "@/components/workspace/items/create-item-dialog";
import { ItemFilters } from "@/components/workspace/items/item-filters";
import { ItemList } from "@/components/workspace/items/item-list";
import { listWorkItems } from "@/lib/workspace/items-server";
import { roleAtLeast } from "@/lib/workspace/roles";
import { getWorkspace, listWorkspaceMembers, listWorkspaceTracks } from "@/lib/workspace/server";
import type { ItemType } from "@/lib/workspace/types";

export const metadata: Metadata = {
  title: "Items",
};

interface PageProps {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ type?: string; status?: string; track?: string; assignee?: string; q?: string }>;
}

export default async function WorkspaceListPage({ params, searchParams }: PageProps) {
  const { id } = await params;
  const sp = await searchParams;

  const [workspace, tracks, members, page] = await Promise.all([
    getWorkspace(id),
    listWorkspaceTracks(id),
    listWorkspaceMembers(id),
    listWorkItems(id, {
      type: sp.type as ItemType | undefined,
      status: sp.status,
      track: sp.track,
      assignee: sp.assignee,
      q: sp.q,
      limit: 30,
    }),
  ]);

  const allowedTypes: ItemType[] = [];
  if (roleAtLeast(workspace.my_role, "manager")) allowedTypes.push("epic", "feature");
  else if (workspace.led_track_ids.length > 0) allowedTypes.push("feature");
  if (workspace.my_role !== "viewer") allowedTypes.push("task", "bug", "subtask");

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <ItemFilters showStatus members={members} tracks={tracks} />
        {allowedTypes.length > 0 && <CreateItemDialog allowedTypes={allowedTypes} tracks={tracks} workspaceId={id} />}
      </div>
      <ItemList initialPage={page} workspaceId={id} />
    </div>
  );
}
