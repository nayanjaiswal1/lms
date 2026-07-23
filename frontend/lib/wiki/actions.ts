"use server";

import type { JSONContent } from "@tiptap/react";

import { apiAction, apiUpload } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import type { WikiComment, WikiPage, WikiSpace, WikiTemplate } from "@/lib/server/wiki";

export async function createSpaceAction(payload: {
  name: string;
  description?: string;
  icon?: string;
  visibility?: "members" | "public";
  course_id?: string;
}): Promise<ActionResult<WikiSpace>> {
  return apiAction<WikiSpace>("POST", "/api/wiki/spaces", payload);
}

export async function updateSpaceAction(
  id: string,
  payload: { name?: string; description?: string; icon?: string; visibility?: "members" | "public" },
): Promise<ActionResult<WikiSpace>> {
  return apiAction<WikiSpace>("PATCH", `/api/wiki/spaces/${id}`, payload);
}

export async function deleteSpaceAction(id: string): Promise<ActionResult<{ deleted: boolean }>> {
  return apiAction<{ deleted: boolean }>("DELETE", `/api/wiki/spaces/${id}`);
}

export async function createPageAction(
  spaceId: string,
  payload: { title: string; parent_id?: string; emoji?: string; template_id?: string },
): Promise<ActionResult<WikiPage>> {
  return apiAction<WikiPage>("POST", `/api/wiki/spaces/${spaceId}/pages`, payload);
}

export async function updatePageAction(
  id: string,
  payload: {
    title?: string;
    content?: JSONContent;
    status?: "draft" | "published";
    emoji?: string;
    order_index?: number;
    parent_id?: string;
  },
): Promise<ActionResult<WikiPage>> {
  return apiAction<WikiPage>("PATCH", `/api/wiki/pages/${id}`, payload);
}

export async function movePageAction(
  id: string,
  payload: { parent_id: string | null; order_index: number },
): Promise<ActionResult<WikiPage>> {
  return apiAction<WikiPage>("POST", `/api/wiki/pages/${id}/move`, payload);
}

export async function deletePageAction(id: string): Promise<ActionResult<{ deleted: boolean }>> {
  return apiAction<{ deleted: boolean }>("DELETE", `/api/wiki/pages/${id}`);
}

export async function restoreVersionAction(pageId: string, version: number): Promise<ActionResult<WikiPage>> {
  return apiAction<WikiPage>("POST", `/api/wiki/pages/${pageId}/versions/${version}/restore`);
}

export async function createCommentAction(
  pageId: string,
  payload: { content: string; parent_id?: string },
): Promise<ActionResult<WikiComment>> {
  return apiAction<WikiComment>("POST", `/api/wiki/pages/${pageId}/comments`, payload);
}

export async function updateCommentAction(id: string, content: string): Promise<ActionResult<WikiComment>> {
  return apiAction<WikiComment>("PATCH", `/api/wiki/comments/${id}`, { content });
}

export async function deleteCommentAction(id: string): Promise<ActionResult<{ deleted: boolean }>> {
  return apiAction<{ deleted: boolean }>("DELETE", `/api/wiki/comments/${id}`);
}

export async function createTemplateAction(payload: {
  name: string;
  description?: string;
  content: JSONContent;
}): Promise<ActionResult<WikiTemplate>> {
  return apiAction<WikiTemplate>("POST", "/api/wiki/templates", payload);
}

export async function deleteTemplateAction(id: string): Promise<ActionResult<{ deleted: boolean }>> {
  return apiAction<{ deleted: boolean }>("DELETE", `/api/wiki/templates/${id}`);
}

// Wiki image embeds reuse the generic upload endpoint (see frontend/CLAUDE.md
// "File upload pattern") — no wiki-specific upload route on the backend.
export async function uploadWikiImageAction(formData: FormData): Promise<ActionResult<{ url: string; storage_key: string }>> {
  return apiUpload<{ url: string; storage_key: string }>("/api/upload", formData);
}
