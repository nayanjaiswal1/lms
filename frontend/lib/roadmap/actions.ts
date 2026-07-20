"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { Roadmap } from "@/lib/server/roadmap";

export interface CreateRoadmapInput {
  title?: string;
  goal_description: string;
  target_role?: string;
  skill_level?: string;
  timeframe_weeks?: number;
  focus_areas?: string[];
}

export async function createRoadmapAction(input: CreateRoadmapInput): Promise<ActionResult<Roadmap>> {
  const result = await apiAction<Roadmap>("POST", "/api/roadmaps", input);
  if (result.ok) revalidatePath(ROUTES.ROADMAP);
  return result;
}

export async function regenerateRoadmapAction(id: string): Promise<ActionResult<Roadmap>> {
  const result = await apiAction<Roadmap>("POST", `/api/roadmaps/${id}/regenerate`);
  if (result.ok) revalidatePath(ROUTES.roadmap(id));
  return result;
}

export async function startRoadmapAction(id: string): Promise<ActionResult<Roadmap>> {
  const result = await apiAction<Roadmap>("POST", `/api/roadmaps/${id}/start`);
  if (result.ok) revalidatePath(ROUTES.ROADMAP);
  return result;
}

export async function updateRoadmapAction(
  id: string,
  input: { title?: string; status?: string; is_public?: boolean },
): Promise<ActionResult<Roadmap>> {
  const result = await apiAction<Roadmap>("PATCH", `/api/roadmaps/${id}`, input);
  if (result.ok) {
    revalidatePath(ROUTES.roadmap(id));
    revalidatePath(ROUTES.ROADMAP);
  }
  return result;
}

export async function deleteRoadmapAction(id: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/roadmaps/${id}`);
  if (result.ok) revalidatePath(ROUTES.ROADMAP);
  return result;
}

export async function updateModuleProgressAction(
  roadmapId: string,
  moduleId: string,
  completed: boolean,
): Promise<ActionResult<Roadmap>> {
  const result = await apiAction<Roadmap>(
    "POST",
    `/api/roadmaps/${roadmapId}/modules/${moduleId}/progress`,
    { completed },
  );
  if (result.ok) revalidatePath(ROUTES.roadmap(roadmapId));
  return result;
}

export async function deleteModuleAction(roadmapId: string, moduleId: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/roadmaps/${roadmapId}/modules/${moduleId}`);
  if (result.ok) revalidatePath(ROUTES.roadmap(roadmapId));
  return result;
}
