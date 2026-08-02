"use server";
import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export interface SnippetResult {
  exit_ok: boolean;
  stdout: string;
  stderr: string;
}

// Runs a standalone lesson code snippet through the backend Piston executor.
// No lab session involved — see POST /api/labs/run.
export async function runSnippetAction(
  language: string,
  code: string,
): Promise<ActionResult<SnippetResult>> {
  return apiAction<SnippetResult>("POST", "/api/labs/run", { language, code });
}

// Permanently removes one of the caller's own self-courses (kind='self') —
// only the owner can, enforced server-side by DeleteOwnedSelfCourse.
export async function deleteSelfCourseAction(courseID: string): Promise<ActionResult<undefined>> {
  const result = await apiAction<undefined>("DELETE", `/api/self-courses/${courseID}`);
  if (result.ok) revalidatePath(ROUTES.DASHBOARD);
  return result;
}

// Removes one module from one of the caller's own self-courses (kind='self')
// — only the owner can, enforced server-side by DeleteSelfCourseModule.
export async function deleteSelfCourseModuleAction(
  courseSlug: string,
  moduleID: string,
): Promise<ActionResult<undefined>> {
  const result = await apiAction<undefined>("DELETE", `/api/self-course-modules/${moduleID}`);
  if (result.ok) revalidatePath(ROUTES.courseLearn(courseSlug));
  return result;
}
