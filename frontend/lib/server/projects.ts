"use server";

import { apiGet } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";

// Lightweight personal project list — a Linked Task Board link target, not
// the org-scoped project_requirements marketplace board.
export interface Project {
  id: string;
  name: string;
  description: string;
}

export async function listProjectsAction(): Promise<ActionResult<Project[]>> {
  try {
    const projects = await apiGet<Project[]>("/api/projects");
    return { ok: true, data: projects };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Could not load projects." };
  }
}

