"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import type { LabSession } from "@/lib/labs";
import type {
  AffectedLab,
  PublishResult,
  Recipe,
  RecipeSpec,
  TargetPlacement,
  TextBlockManifest,
  TicketDraft,
} from "@/lib/labs/builder/types";
import ROUTES from "@/lib/routes";

const BASE = "/api/instructor/lab-authoring";

interface CreateRecipeInput {
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


export async function startBuildAction(recipeId: string): Promise<ActionResult<{ build_id: string; reused: boolean }>> {
  const res = await apiAction<{ build_id: string; reused: boolean }>("POST", `${BASE}/recipes/${recipeId}/builds`);
  revalidatePath(ROUTES.labBuilderRecipe(recipeId));
  return res;
}

export async function startPreviewAction(buildId: string, variantKey: string): Promise<ActionResult<LabSession>> {
  return apiAction<LabSession>("POST", `${BASE}/builds/${buildId}/preview-session`, { variant_key: variantKey });
}

interface PublishInput {
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

// ── Org text blocks (ticket / hints / rubric / preset) ───────────────────────

export async function createTextBlockAction(
  manifest: TextBlockManifest,
): Promise<ActionResult<{ block_id: string; version_id: string }>> {
  const res = await apiAction<{ block_id: string; version_id: string }>("POST", `${BASE}/blocks`, manifest);
  if (res.ok) revalidatePath(ROUTES.LAB_BUILDER_BLOCKS);
  return res;
}

/** Saves a new immutable version of an org text block. */
export async function updateTextBlockAction(
  blockId: string,
  manifest: TextBlockManifest,
): Promise<ActionResult<{ block_id: string; version_id: string }>> {
  const res = await apiAction<{ block_id: string; version_id: string }>("PUT", `${BASE}/blocks/${blockId}`, manifest);
  if (res.ok) revalidatePath(ROUTES.labBuilderBlock(blockId));
  return res;
}

export async function deleteTextBlockAction(blockId: string): Promise<ActionResult> {
  const res = await apiAction("DELETE", `${BASE}/blocks/${blockId}`);
  if (res.ok) revalidatePath(ROUTES.LAB_BUILDER_BLOCKS);
  return res;
}

/** AI ticket draft for the recipe; cached server-side per (composition, persona). */
export async function draftTicketAction(recipeId: string, persona: string): Promise<ActionResult<TicketDraft>> {
  return apiAction<TicketDraft>("POST", `${BASE}/recipes/${recipeId}/ticket-draft`, { persona });
}

// ── Yank (platform super_admin) ──────────────────────────────────────────────

const ADMIN_BASE = "/api/admin/lab-authoring/blocks";

export async function getAffectedLabsAction(versionId: string): Promise<ActionResult<{ affected_labs: AffectedLab[] }>> {
  return apiAction<{ affected_labs: AffectedLab[] }>("GET", `${ADMIN_BASE}/${versionId}/affected-labs`);
}

export async function yankVersionAction(
  blockId: string,
  versionId: string,
  reason: string,
): Promise<ActionResult<{ affected_labs: AffectedLab[] }>> {
  const res = await apiAction<{ affected_labs: AffectedLab[] }>("POST", `${ADMIN_BASE}/${versionId}/yank`, { reason });
  if (res.ok) revalidatePath(ROUTES.labBuilderBlock(blockId));
  return res;
}
