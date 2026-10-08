import "server-only";

import { apiGet } from "@/lib/server/api";
import type {
  BriefView,
  DocView,
  Meeting,
  Page,
  RequirementQuestion,
  Standup,
} from "@/lib/workspace/types";

// The contract's Phase 3 comment routes (questions/{id}/comments,
// items/{id}/comments) reuse the existing `comments` table with
// `subject_type` widened to `work_item` | `requirement_question`, but
// types.ts (lead-owned) has no response shape for it — WikiComment
// (lib/server/wiki.ts) is page-scoped and threaded, which this flat,
// unthreaded contract doesn't ask for.
export interface WorkspaceComment {
  id: string;
  subject_type: "work_item" | "requirement_question";
  subject_id: string;
  author_id: string | null;
  author_name: string;
  content: string;
  created_at: string;
}

function pageQuery(cursor?: string, limit?: number): string {
  const params = new URLSearchParams();
  if (cursor) params.set("cursor", cursor);
  if (limit) params.set("limit", String(limit));
  const qs = params.toString();
  return qs ? `?${qs}` : "";
}

export async function listWorkspaceQuestions(workspaceId: string, cursor?: string, limit?: number): Promise<Page<RequirementQuestion>> {
  return apiGet<Page<RequirementQuestion>>(`/api/workspaces/${workspaceId}/questions${pageQuery(cursor, limit)}`);
}

export async function getWorkspaceBrief(workspaceId: string): Promise<BriefView> {
  return apiGet<BriefView>(`/api/workspaces/${workspaceId}/brief`);
}

export async function getItemDoc(workspaceId: string, itemId: string): Promise<DocView> {
  return apiGet<DocView>(`/api/workspaces/${workspaceId}/items/${itemId}/doc`);
}

export async function listWorkspaceMeetings(workspaceId: string, cursor?: string, limit?: number): Promise<Page<Meeting>> {
  return apiGet<Page<Meeting>>(`/api/workspaces/${workspaceId}/meetings${pageQuery(cursor, limit)}`);
}

export async function listWorkspaceStandups(workspaceId: string, day?: string): Promise<Standup[]> {
  const qs = day ? `?day=${encodeURIComponent(day)}` : "";
  return apiGet<Standup[]>(`/api/workspaces/${workspaceId}/standups${qs}`);
}


export async function listItemComments(workspaceId: string, itemId: string, cursor?: string, limit?: number): Promise<Page<WorkspaceComment>> {
  return apiGet<Page<WorkspaceComment>>(`/api/workspaces/${workspaceId}/items/${itemId}/comments${pageQuery(cursor, limit)}`);
}
