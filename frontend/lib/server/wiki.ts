import "server-only";
import type { JSONContent } from "@tiptap/react";

import { apiGet } from "@/lib/server/api";

export interface WikiSpace {
  id: string;
  org_id: string;
  course_id?: string | null;
  name: string;
  slug: string;
  description?: string | null;
  icon?: string | null;
  visibility: "members" | "public";
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface WikiPageTreeNode {
  id: string;
  parent_id?: string | null;
  title: string;
  slug: string;
  emoji?: string | null;
  order_index: number;
  status: "draft" | "published";
  children: WikiPageTreeNode[];
}

export interface WikiSpaceWithTree extends WikiSpace {
  tree: WikiPageTreeNode[];
}

export interface WikiPage {
  id: string;
  space_id: string;
  parent_id?: string | null;
  title: string;
  slug: string;
  content: JSONContent;
  order_index: number;
  status: "draft" | "published";
  emoji?: string | null;
  version: number;
  created_by: string;
  updated_by?: string | null;
  created_at: string;
  updated_at: string;
}

export interface WikiBreadcrumbItem {
  id: string;
  title: string;
  slug: string;
}

export interface WikiPageDetail extends WikiPage {
  space_slug: string;
  space_name: string;
  breadcrumb: WikiBreadcrumbItem[];
}

export interface WikiPageVersionSummary {
  version: number;
  title: string;
  saved_by: string;
  saved_at: string;
}

export interface WikiPageVersionDetail extends WikiPageVersionSummary {
  content: JSONContent;
}

export interface WikiComment {
  id: string;
  page_id: string;
  parent_id?: string | null;
  author_id: string;
  content: string;
  deleted: boolean;
  created_at: string;
  updated_at: string;
}

export interface WikiCommentThread extends WikiComment {
  replies: WikiComment[];
}

export interface WikiTemplate {
  id: string;
  org_id?: string | null;
  name: string;
  description?: string | null;
  content: JSONContent;
  created_by?: string | null;
  created_at: string;
}

export interface WikiSearchResult {
  page_id: string;
  title: string;
  space_name: string;
  space_slug: string;
  excerpt: string;
  updated_at: string;
}

export async function getWikiSpaces(): Promise<WikiSpace[]> {
  return apiGet<WikiSpace[]>("/api/wiki/spaces");
}

export async function getWikiSpace(spaceSlug: string): Promise<WikiSpaceWithTree> {
  return apiGet<WikiSpaceWithTree>(`/api/wiki/spaces/${spaceSlug}`);
}

export async function getWikiPageTree(spaceId: string): Promise<WikiPageTreeNode[]> {
  return apiGet<WikiPageTreeNode[]>(`/api/wiki/spaces/${spaceId}/pages`);
}

export async function getWikiPage(pageId: string): Promise<WikiPageDetail> {
  return apiGet<WikiPageDetail>(`/api/wiki/pages/${pageId}`);
}

export async function getWikiPageVersions(pageId: string): Promise<WikiPageVersionSummary[]> {
  return apiGet<WikiPageVersionSummary[]>(`/api/wiki/pages/${pageId}/versions`);
}

export async function getWikiPageVersion(pageId: string, version: number): Promise<WikiPageVersionDetail> {
  return apiGet<WikiPageVersionDetail>(`/api/wiki/pages/${pageId}/versions/${version}`);
}

export async function getWikiComments(pageId: string): Promise<WikiCommentThread[]> {
  return apiGet<WikiCommentThread[]>(`/api/wiki/pages/${pageId}/comments`);
}

export async function getWikiTemplates(): Promise<WikiTemplate[]> {
  return apiGet<WikiTemplate[]>("/api/wiki/templates");
}

export async function searchWiki(query: string, spaceSlug?: string): Promise<WikiSearchResult[]> {
  const params = new URLSearchParams({ q: query });
  if (spaceSlug) params.set("space", spaceSlug);
  return apiGet<WikiSearchResult[]>(`/api/wiki/search?${params.toString()}`);
}

/** Resolves a `[...path]` URL segment chain (page slugs from the space root)
 * against an already-fetched tree to the target page ID — avoids a dedicated
 * "resolve by path" backend endpoint. Returns null if the path doesn't match. */
export function resolvePageIdFromPath(tree: WikiPageTreeNode[], path: string[]): string | null {
  let nodes = tree;
  let matched: WikiPageTreeNode | null = null;
  for (const segment of path) {
    matched = nodes.find((n) => n.slug === segment) ?? null;
    if (!matched) return null;
    nodes = matched.children;
  }
  return matched?.id ?? null;
}
