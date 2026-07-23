import "server-only";

import { apiGet } from "@/lib/server/api";

export interface CohortGroup {
  id: string;
  org_id: string;
  parent_id: string | null;
  name: string;
  slug: string;
  level_label: string | null;
  status: string;
  batch_count: number;
  child_count: number;
  created_at: string;
}

export async function getCohortGroups(): Promise<CohortGroup[]> {
  const data = await apiGet<{ groups: CohortGroup[] }>("/api/cohort-groups");
  return data.groups ?? [];
}

export async function getCohortGroup(id: string): Promise<CohortGroup> {
  return apiGet<CohortGroup>(`/api/cohort-groups/${id}`);
}

export interface CohortGroupNode extends CohortGroup {
  children: CohortGroupNode[];
}

// buildCohortTree assembles the flat list ListCohortGroups returns into a
// tree — shared by the admin manage page and the leaderboard scope picker so
// both walk the same structure.
export function buildCohortTree(flat: CohortGroup[]): CohortGroupNode[] {
  const nodes = new Map<string, CohortGroupNode>();
  for (const g of flat) nodes.set(g.id, { ...g, children: [] });

  const roots: CohortGroupNode[] = [];
  for (const node of nodes.values()) {
    const parent = node.parent_id ? nodes.get(node.parent_id) : undefined;
    if (parent) {
      parent.children.push(node);
    } else {
      roots.push(node);
    }
  }
  return roots;
}

export interface FlatCohortOption {
  id: string;
  label: string; // breadcrumb, e.g. "Class 10 / Section A"
}

// flattenCohortOptions walks the tree depth-first and produces breadcrumb
// labels — used by the "move batch to group" select, where a plain name list
// would be ambiguous once two groups share a name under different parents.
export function flattenCohortOptions(roots: CohortGroupNode[], prefix = ""): FlatCohortOption[] {
  const out: FlatCohortOption[] = [];
  for (const node of roots) {
    const label = prefix ? `${prefix} / ${node.name}` : node.name;
    out.push({ id: node.id, label });
    out.push(...flattenCohortOptions(node.children, label));
  }
  return out;
}
