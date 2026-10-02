import { notFound } from "next/navigation";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { apiGet, apiPost } from "@/lib/server/api";
import { getMyPermissions } from "@/lib/server/permissions";
import type {
  BlockDetail,
  BlockSummary,
  BuildView,
  Candidate,
  CoursePickerOption,
  PickerOption,
  Recipe,
  RecipeAnalysis,
  RecipeView,
} from "@/lib/labs/builder/types";

// Server Component reads for the builder pages (app/(app)/teach/debug-labs).

const BASE = "/api/instructor/lab-authoring";

/** Page guard: the builder is for lab authors only (the API enforces it too). */
export async function requireLabAuthor(): Promise<string[]> {
  const perms = await getMyPermissions();
  if (!perms.includes(PERMISSIONS.LABAUTHOR.COMPOSE)) notFound();
  return perms;
}

export async function getRecipes(): Promise<Recipe[]> {
  return apiGet<Recipe[]>(`${BASE}/recipes`);
}

export async function getRecipeView(id: string): Promise<RecipeView> {
  return apiGet<RecipeView>(`${BASE}/recipes/${id}`);
}

/** Side-effect free on the backend; POST only because validation is an action verb there. */
export async function validateRecipe(id: string): Promise<RecipeAnalysis> {
  return apiPost<RecipeAnalysis>(`${BASE}/recipes/${id}/validate`, {});
}

export async function getCandidates(id: string, kind: string): Promise<Candidate[]> {
  return apiGet<Candidate[]>(`${BASE}/recipes/${id}/candidates?kind=${encodeURIComponent(kind)}`);
}

export async function getBuild(id: string): Promise<BuildView> {
  return apiGet<BuildView>(`${BASE}/builds/${id}`);
}

export interface BlockListFilter {
  kind?: string;
  stack?: string;
  category?: string;
}

export async function getBlocks(filter: BlockListFilter = {}): Promise<BlockSummary[]> {
  const qs = new URLSearchParams();
  for (const [k, v] of Object.entries(filter)) if (v) qs.set(k, v);
  const q = qs.toString();
  return apiGet<BlockSummary[]>(`${BASE}/blocks${q ? `?${q}` : ""}`);
}

export async function getBlock(id: string): Promise<BlockDetail> {
  return apiGet<BlockDetail>(`${BASE}/blocks/${id}`);
}

/** The caller's courses, for the publish placement picker. */
export async function getInstructorCourses(): Promise<CoursePickerOption[]> {
  const res = await apiGet<{ courses: CoursePickerOption[] }>("/api/courses?role=instructor&limit=100");
  return res.courses;
}

export async function getCourseSections(courseId: string): Promise<PickerOption[]> {
  const res = await apiGet<{ sections: PickerOption[] }>(`/api/courses/${courseId}`);
  return res.sections;
}
