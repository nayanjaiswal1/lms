"use server";

import { revalidatePath } from "next/cache";
import { apiAction, apiUpload, ActionResult } from "@/lib/server/api";
import type { AwardResult } from "@/lib/server/rewards";
import ROUTES from "@/lib/routes";

interface ProgressResult {
  progress: unknown;
  rewards?: AwardResult;
}

export async function createCourseAction(input: {
  title:       string;
  description?: string;
  cover_url?:  string;
  difficulty?: string;
  tags?:       string[];
  is_free?:    boolean;
}): Promise<ActionResult<{ id: string; slug: string }>> {
  const result = await apiAction<{ id: string; slug: string }>("POST", "/api/courses", input);
  if (result.ok) revalidatePath(ROUTES.MANAGE_COURSES);
  return result;
}

export async function enrollAction(courseID: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/courses/${courseID}/enroll`);
  if (result.ok) revalidatePath(ROUTES.COURSES);
  return result;
}

export async function updateProgressAction(input: {
  moduleID: string;
  status: "not_started" | "in_progress" | "completed";
  last_position_seconds?: number;
}): Promise<ActionResult<ProgressResult>> {
  return apiAction<ProgressResult>("PATCH", `/api/modules/${input.moduleID}/progress`, {
    status: input.status,
    last_position_seconds: input.last_position_seconds ?? 0,
  });
}

export async function createModuleAction(input: {
  course_id: string;
  section_id: string;
  title: string;
  type: string;
  content_body?: string;
  estimated_minutes?: number;
}): Promise<ActionResult> {
  return apiAction("POST", `/api/sections/${input.section_id}/modules`, {
    title:             input.title,
    type:              input.type,
    content_body:      input.content_body,
    estimated_minutes: input.estimated_minutes,
  });
}

export async function updateCourseAction(
  courseId: string,
  input: {
    title: string;
    description?: string;
    cover_url?: string;
    difficulty: string;
    tags: string[];
    is_free: boolean;
  },
): Promise<ActionResult> {
  const body: Record<string, unknown> = {
    title: input.title,
    difficulty: input.difficulty,
    tags: input.tags,
    is_free: input.is_free,
    price_cents: 0,
  };
  if (input.description !== undefined) body.description = input.description;
  if (input.cover_url !== undefined && input.cover_url !== "") body.cover_url = input.cover_url;

  const result = await apiAction("PATCH", `/api/courses/${courseId}`, body);
  if (result.ok) {
    revalidatePath(ROUTES.manageCourse(courseId));
    revalidatePath(ROUTES.MANAGE_COURSES);
  }
  return result;
}

export async function generateOutlineAction(input: {
  topic: string;
  level: string;
  module_count: number;
}): Promise<ActionResult<unknown>> {
  return apiAction<unknown>("POST", "/api/courses/generate-outline", input);
}

export async function createSectionAction(input: {
  course_id: string;
  title:     string;
  position?: number;
}): Promise<ActionResult<{ id: string }>> {
  return apiAction<{ id: string }>("POST", `/api/courses/${input.course_id}/sections`, {
    title: input.title,
    position: input.position,
  });
}

export async function uploadAssetAction(
  formData: FormData,
): Promise<ActionResult<{ url: string; storage_key: string }>> {
  return apiUpload<{ url: string; storage_key: string }>("/api/upload", formData);
}
