"use server";

import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import type { LabSession } from "@/lib/labs";
import type { AttachLibraryItemInput, LibraryItemPage, LibraryKind, LibraryListFilter } from "@/lib/library/types";

function listQuery(filter: LibraryListFilter): string {
  const params = new URLSearchParams();
  if (filter.types && filter.types.length > 0) params.set("type", filter.types.join(","));
  if (filter.q) params.set("q", filter.q);
  if (filter.cursor) params.set("cursor", filter.cursor);
  const qs = params.toString();
  return qs ? `?${qs}` : "";
}

// Read through a server action (not apiGet in a server component) because
// the picker dialog searches interactively — same pattern
// lib/workspace/items-actions.ts's searchWorkItemsAction uses.
export async function listLibraryItemsAction(filter: LibraryListFilter): Promise<ActionResult<LibraryItemPage>> {
  return apiAction<LibraryItemPage>("GET", `/api/library${listQuery(filter)}`);
}

export async function previewLibraryItemAction(kind: LibraryKind, id: string): Promise<ActionResult<unknown>> {
  return apiAction<unknown>("GET", `/api/library/${kind}/${id}/preview`);
}

export async function tryLibraryItemAction(kind: LibraryKind, id: string): Promise<ActionResult<LabSession>> {
  return apiAction<LabSession>("POST", `/api/library/${kind}/${id}/try`);
}

// ── "Add to course…" course/section pickers for the standalone /library page ──
// Fetched via server actions (not lib/courses/* — a cross-feature import the
// boundaries lint would flag) straight against the same backend endpoints
// the courses feature itself calls.

export interface CoursePickerOption { id: string; title: string; slug: string }
export interface SectionPickerOption { id: string; title: string }

export async function listCoursesForPickerAction(): Promise<ActionResult<CoursePickerOption[]>> {
  const result = await apiAction<{ courses: CoursePickerOption[] }>("GET", "/api/courses?role=instructor&limit=100");
  if (!result.ok || !result.data) return { error: result.error };
  return { ok: true, data: result.data.courses };
}

export async function listSectionsForPickerAction(courseId: string): Promise<ActionResult<SectionPickerOption[]>> {
  const result = await apiAction<{ sections: SectionPickerOption[] }>("GET", `/api/courses/${courseId}`);
  if (!result.ok || !result.data) return { error: result.error };
  return { ok: true, data: result.data.sections };
}

export async function attachLibraryItemAction(
  sectionId: string,
  input: AttachLibraryItemInput,
): Promise<ActionResult<{ id: string }>> {
  return apiAction<{ id: string }>("POST", `/api/sections/${sectionId}/library-items`, input);
}
