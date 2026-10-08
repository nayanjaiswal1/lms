"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { ItemListFilter } from "@/lib/workspace/items-server";
import type {
  Assignee,
  AssigneeInput,
  CreateWorkItemInput,
  CreateWorkItemResult,
  ItemLink,
  LinkKind,
  Page,
  SimilarItem,
  TransitionInput,
  UpdateWorkItemInput,
  WorkItem,
} from "@/lib/workspace/types";

// ── Request-body shapes the contract names (MoveWorkItemRequest,
// SetAssigneesRequest, CreateLinkRequest) but that types.ts (lead-owned)
// doesn't declare. ──


interface SetAssigneesInput {
  assignees: AssigneeInput[];
}

interface CreateLinkInput {
  to_item_id: string;
  kind: LinkKind;
}

function itemPath(workspaceId: string, itemId: string): string {
  return `/api/workspaces/${workspaceId}/items/${itemId}`;
}

// The item detail route is keyed by `key` (PAY-12), not the `itemId` (uuid)
// these actions receive, so it can't be targeted with revalidatePath from
// here — callers on that page call router.refresh() themselves after a
// successful mutation instead (see transition-buttons.tsx etc). This only
// keeps the board/list caches (keyed by workspaceId, which we do have) fresh.
function revalidateItem(workspaceId: string, _itemKeyOrId: string) {
  revalidatePath(ROUTES.workspaceBoard(workspaceId));
  revalidatePath(ROUTES.workspaceList(workspaceId));
}

// ── Reads exposed as actions so client components can call them without an
// effect-driven fetch (search-as-you-type parent/blocker pickers, similar-item
// duplicate check) — apiAction never throws, unlike apiGet, which is what a
// debounced client call needs. ──────────────────────────────────────────────

export async function searchWorkItemsAction(workspaceId: string, filter: ItemListFilter): Promise<ActionResult<Page<WorkItem>>> {
  const params = new URLSearchParams();
  const types = Array.isArray(filter.type) ? filter.type : filter.type ? [filter.type] : [];
  for (const t of types) params.append("type", t);
  if (filter.status) params.set("status", filter.status);
  if (filter.q) params.set("q", filter.q);
  if (filter.limit) params.set("limit", String(filter.limit));
  return apiAction<Page<WorkItem>>("GET", `/api/workspaces/${workspaceId}/items?${params.toString()}`);
}

export async function listSimilarItemsAction(workspaceId: string, q: string): Promise<ActionResult<SimilarItem[]>> {
  return apiAction<SimilarItem[]>("GET", `/api/workspaces/${workspaceId}/items/similar?q=${encodeURIComponent(q)}`);
}

// ── Mutations ────────────────────────────────────────────────────────────────

export async function createWorkItemAction(workspaceId: string, input: CreateWorkItemInput): Promise<ActionResult<CreateWorkItemResult>> {
  const result = await apiAction<CreateWorkItemResult>("POST", `/api/workspaces/${workspaceId}/items`, input);
  if (result.ok) {
    revalidatePath(ROUTES.workspaceBoard(workspaceId));
    revalidatePath(ROUTES.workspaceList(workspaceId));
    if (input.parent_id) revalidateItem(workspaceId, input.parent_id);
  }
  return result;
}

export async function updateWorkItemAction(
  workspaceId: string,
  itemId: string,
  input: UpdateWorkItemInput,
): Promise<ActionResult<WorkItem>> {
  const result = await apiAction<WorkItem>("PATCH", itemPath(workspaceId, itemId), input);
  if (result.ok) revalidateItem(workspaceId, itemId);
  return result;
}


export async function archiveWorkItemAction(workspaceId: string, itemId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `${itemPath(workspaceId, itemId)}/archive`);
  if (result.ok) {
    revalidatePath(ROUTES.workspaceBoard(workspaceId));
    revalidatePath(ROUTES.workspaceList(workspaceId));
  }
  return result;
}

export async function deleteWorkItemAction(workspaceId: string, itemId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", itemPath(workspaceId, itemId));
  if (result.ok) {
    revalidatePath(ROUTES.workspaceBoard(workspaceId));
    revalidatePath(ROUTES.workspaceList(workspaceId));
  }
  return result;
}

export async function transitionItemAction(
  workspaceId: string,
  itemId: string,
  input: TransitionInput,
): Promise<ActionResult<WorkItem>> {
  const result = await apiAction<WorkItem>("POST", `${itemPath(workspaceId, itemId)}/transition`, input);
  if (result.ok) {
    revalidateItem(workspaceId, itemId);
    if (input.blocker_item_id) revalidateItem(workspaceId, input.blocker_item_id);
  }
  return result;
}

export async function setAssigneesAction(
  workspaceId: string,
  itemId: string,
  assignees: AssigneeInput[],
): Promise<ActionResult<Assignee[]>> {
  const result = await apiAction<Assignee[]>(
    "PUT",
    `${itemPath(workspaceId, itemId)}/assignees`,
    { assignees } satisfies SetAssigneesInput,
  );
  if (result.ok) revalidateItem(workspaceId, itemId);
  return result;
}

export async function createLinkAction(
  workspaceId: string,
  itemId: string,
  input: CreateLinkInput,
): Promise<ActionResult<ItemLink>> {
  const result = await apiAction<ItemLink>("POST", `${itemPath(workspaceId, itemId)}/links`, input);
  if (result.ok) {
    revalidateItem(workspaceId, itemId);
    revalidateItem(workspaceId, input.to_item_id);
  }
  return result;
}

export async function deleteLinkAction(
  workspaceId: string,
  itemId: string,
  toItemId: string,
  kind: LinkKind,
): Promise<ActionResult> {
  const result = await apiAction("DELETE", `${itemPath(workspaceId, itemId)}/links/${toItemId}/${kind}`);
  if (result.ok) {
    revalidateItem(workspaceId, itemId);
    revalidateItem(workspaceId, toItemId);
  }
  return result;
}
