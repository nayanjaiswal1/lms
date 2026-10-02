"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import type { LabSession } from "@/lib/labs";
import type { PublishResult, Recipe, RecipeSpec, TargetPlacement } from "@/lib/labs/builder/types";
import ROUTES from "@/lib/routes";

const BASE = "/api/instructor/lab-authoring";

export interface CreateRecipeInput {
  title: string;
  appVersionId: string;
  placement: TargetPlacement | null;
}

export async function createRecipeAction(input: CreateRecipeInput): Promise<ActionResult<Recipe>> {
  return apiAction<Recipe>("POST", `${BASE}/recipes`, {
    lab_kind: "debug",
    title: input.title,
    spec: { blocks: [{ block_version_id: input.appVersionId }] },
    target_placement: input.placement,
  });
}

/** Saves a new spec under optimistic concurrency (409 when someone else saved first). */
export async function saveRecipeSpecAction(
  recipe: Pick<Recipe, "id" | "title" | "revision" | "target_placement">,
  spec: RecipeSpec,
): Promise<ActionResult<Recipe>> {
  const res = await apiAction<Recipe>("PUT", `${BASE}/recipes/${recipe.id}`, {
    title: recipe.title,
    spec,
    target_placement: recipe.target_placement,
    revision: recipe.revision,
  });
  revalidatePath(ROUTES.labBuilderRecipe(recipe.id));
  return res;
}

export async function deleteRecipeAction(id: string): Promise<ActionResult> {
  const res = await apiAction("DELETE", `${BASE}/recipes/${id}`);
  if (res.ok) revalidatePath(ROUTES.LAB_BUILDER);
  return res;
}

export async function startBuildAction(recipeId: string): Promise<ActionResult<{ build_id: string; reused: boolean }>> {
  const res = await apiAction<{ build_id: string; reused: boolean }>("POST", `${BASE}/recipes/${recipeId}/builds`);
  revalidatePath(ROUTES.labBuilderRecipe(recipeId));
  return res;
}

export async function startPreviewAction(buildId: string, variantKey: string): Promise<ActionResult<LabSession>> {
  return apiAction<LabSession>("POST", `${BASE}/builds/${buildId}/preview-session`, { variant_key: variantKey });
}

export interface PublishInput {
  courseId: string;
  sectionId: string;
  isRequired: boolean;
}

export async function publishBuildAction(buildId: string, input: PublishInput): Promise<ActionResult<PublishResult>> {
  return apiAction<PublishResult>("POST", `${BASE}/builds/${buildId}/publish`, {
    course_id: input.courseId,
    section_id: input.sectionId,
    is_required: input.isRequired,
  });
}
