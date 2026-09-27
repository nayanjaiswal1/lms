import "server-only";

import { apiGet } from "@/lib/server/api";
import type { ItemDetail, ItemEvent, ItemRef, ItemType, Page, WorkItem } from "@/lib/workspace/types";

export interface ItemListFilter {
  type?: ItemType | ItemType[];
  status?: string;
  track?: string;
  assignee?: string;
  parent?: string;
  feature?: string;
  epic?: string;
  q?: string;
  archived?: boolean;
  cursor?: string;
  limit?: number;
}

function buildItemQuery(filter: ItemListFilter): string {
  const params = new URLSearchParams();
  const types = Array.isArray(filter.type) ? filter.type : filter.type ? [filter.type] : [];
  for (const t of types) params.append("type", t);
  if (filter.status) params.set("status", filter.status);
  if (filter.track) params.set("track", filter.track);
  if (filter.assignee) params.set("assignee", filter.assignee);
  if (filter.parent) params.set("parent", filter.parent);
  if (filter.feature) params.set("feature", filter.feature);
  if (filter.epic) params.set("epic", filter.epic);
  if (filter.q) params.set("q", filter.q);
  if (filter.archived) params.set("archived", "true");
  if (filter.cursor) params.set("cursor", filter.cursor);
  if (filter.limit) params.set("limit", String(filter.limit));
  return params.toString();
}

export async function listWorkItems(workspaceId: string, filter: ItemListFilter): Promise<Page<WorkItem>> {
  const qs = buildItemQuery(filter);
  return apiGet<Page<WorkItem>>(`/api/workspaces/${workspaceId}/items${qs ? `?${qs}` : ""}`);
}

export async function getWorkItem(workspaceId: string, itemRef: string): Promise<ItemDetail> {
  return apiGet<ItemDetail>(`/api/workspaces/${workspaceId}/items/${itemRef}`);
}

export async function listItemEvents(workspaceId: string, itemId: string, cursor?: string, limit = 20): Promise<Page<ItemEvent>> {
  const params = new URLSearchParams();
  if (cursor) params.set("cursor", cursor);
  params.set("limit", String(limit));
  return apiGet<Page<ItemEvent>>(`/api/workspaces/${workspaceId}/items/${itemId}/events?${params.toString()}`);
}

// Item detail's breadcrumb (04-frontend.md §4: "Project / Epic / Feature / KEY")
// needs the epic/feature *titles*, but ItemDetail only carries their ids
// (epic_id/feature_id) plus the immediate parent's ItemRef. Reuse `parent`
// when it already *is* the epic/feature (saves a round trip for
// feature/epic-level items and root bugs) and fetch the rest — at most two
// extra GETs, only for the ids that aren't already covered by `parent`.
export async function getItemAncestors(
  workspaceId: string,
  item: ItemDetail,
): Promise<{ epic: ItemRef | null; feature: ItemRef | null }> {
  const epicFromParent = item.parent?.type === "epic" ? item.parent : null;
  const featureFromParent = item.parent?.type === "feature" ? item.parent : null;

  const needEpic = item.epic_id && !epicFromParent ? item.epic_id : null;
  const needFeature = item.feature_id && !featureFromParent ? item.feature_id : null;

  const [epicFetched, featureFetched] = await Promise.all([
    needEpic ? getWorkItem(workspaceId, needEpic).catch(() => null) : Promise.resolve(null),
    needFeature ? getWorkItem(workspaceId, needFeature).catch(() => null) : Promise.resolve(null),
  ]);

  const toRef = (w: ItemDetail | null): ItemRef | null =>
    w ? { id: w.id, key: w.key, type: w.type, title: w.title, status: w.status } : null;

  return {
    epic: epicFromParent ?? toRef(epicFetched),
    feature: featureFromParent ?? toRef(featureFetched),
  };
}
