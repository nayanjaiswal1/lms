import "server-only";

import { apiGet } from "@/lib/server/api";
import type { DiscoverWorkspace, MyInterest } from "@/lib/workspace/discover-types";
import type { Page } from "@/lib/workspace/types";

export async function listDiscoverWorkspaces(cursor?: string): Promise<Page<DiscoverWorkspace>> {
  const qs = cursor ? `?cursor=${encodeURIComponent(cursor)}` : "";
  return apiGet<Page<DiscoverWorkspace>>(`/api/workspaces/discover${qs}`);
}

export async function listMyWorkspaceInterests(): Promise<MyInterest[]> {
  const res = await apiGet<{ items: MyInterest[] }>(`/api/my/workspace-interests`);
  return res.items;
}
