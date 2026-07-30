"use server";

import { revalidatePath } from "next/cache";
import { apiAction, apiUpload } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import type { AwardResult } from "@/lib/server/rewards";
import type { CertificateRule, FinalTestQuestion, RandomTopic, SubmitFinalTestAttemptResult } from "@/lib/server/courses";
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
  if (result.ok) revalidatePath(ROUTES.COURSES);
  return result;
}

export async function enrollAction(courseID: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/courses/${courseID}/enroll`);
  if (result.ok) revalidatePath(ROUTES.COURSES);
  return result;
}

// Refetches the "surprise me" random-topic pick — used by the client-side
// "Try another" button, since a fresh random pick can't come from a cached
// server-rendered prop.
export async function getRandomTopicAction(): Promise<ActionResult<RandomTopic>> {
  return apiAction<RandomTopic>("GET", "/api/courses/random-topic");
}

export async function submitReviewAction(courseID: string, rating: number): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/courses/${courseID}/reviews`, { rating });
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

interface CheckAttemptResult {
  id: string;
  is_correct: boolean;
}

// Records one submit of an embedded lesson knowledge-check question. mcq
// answers are graded server-side (see backend RecordCheckAttempt) — the
// caller only sends the selection. sql questions have no server-side
// executor, so clientCorrect carries the client-graded (sql.js) result,
// same trust level the pre-existing sql-challenge segment already uses.
export async function recordCheckAttemptAction(input: {
  moduleID: string;
  questionID: string;
  answer: Record<string, unknown>;
  clientCorrect?: boolean;
}): Promise<ActionResult<CheckAttemptResult>> {
  return apiAction<CheckAttemptResult>("POST", `/api/modules/${input.moduleID}/check-attempts`, {
    question_id: input.questionID,
    answer: input.answer,
    client_correct: input.clientCorrect ?? false,
  });
}

// Saves the student's free-text "what did you understand from this lesson"
// reflection — ungraded, one per (user, module), resubmitting overwrites the
// previous answer. Raw input for a future revision-plan / concept-dependency
// -graph feature; not part of the module-complete gate.
export async function submitReflectionAction(input: {
  moduleID: string;
  response: string;
}): Promise<ActionResult> {
  return apiAction("POST", `/api/modules/${input.moduleID}/reflection`, { response: input.response });
}

export async function saveLessonNoteAction(input: {
  moduleID: string;
  content: string;
}): Promise<ActionResult> {
  return apiAction("PUT", `/api/modules/${input.moduleID}/notes`, { content: input.content });
}

export async function createModuleAction(input: {
  course_id: string;
  section_id: string;
  title: string;
  type: string;
  content_body?: string;
  estimated_minutes?: number;
}): Promise<ActionResult<{ id: string }>> {
  return apiAction<{ id: string }>("POST", `/api/sections/${input.section_id}/modules`, {
    title:             input.title,
    type:              input.type,
    content_body:      input.content_body,
    estimated_minutes: input.estimated_minutes,
  });
}

export async function updateCourseAction(
  courseId: string,
  slug: string,
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
    revalidatePath(ROUTES.courseEdit(slug));
    revalidatePath(ROUTES.COURSES);
    revalidatePath(ROUTES.course(slug));
    revalidatePath(ROUTES.DASHBOARD);
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

export async function updateSectionAction(
  sectionId: string,
  input: { title: string },
): Promise<ActionResult> {
  return apiAction("PATCH", `/api/sections/${sectionId}`, { title: input.title });
}

export async function deleteSectionAction(sectionId: string): Promise<ActionResult> {
  return apiAction("DELETE", `/api/sections/${sectionId}`);
}

export async function reorderSectionsAction(
  courseId: string,
  sectionIds: string[],
): Promise<ActionResult> {
  return apiAction("PUT", `/api/courses/${courseId}/sections/order`, { section_ids: sectionIds });
}

export async function updateModuleAction(
  moduleId: string,
  input: {
    title: string;
    type: string;
    content_body?: string;
    estimated_minutes?: number;
    is_free_preview?: boolean;
  },
): Promise<ActionResult> {
  return apiAction("PATCH", `/api/modules/${moduleId}`, {
    title:              input.title,
    type:               input.type,
    content_body:       input.content_body,
    estimated_minutes:  input.estimated_minutes,
    is_free_preview:    input.is_free_preview ?? false,
  });
}

export async function deleteModuleAction(moduleId: string): Promise<ActionResult> {
  return apiAction("DELETE", `/api/modules/${moduleId}`);
}

export async function reorderModulesAction(
  sectionId: string,
  moduleIds: string[],
): Promise<ActionResult> {
  return apiAction("PUT", `/api/sections/${sectionId}/modules/order`, { module_ids: moduleIds });
}

export async function publishCourseAction(courseId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/courses/${courseId}/publish`);
  if (result.ok) {
    // Slug isn't known here — revalidate the dynamic route pattern itself
    // (Next.js resolves this to every matching /courses/{slug}/edit instance).
    revalidatePath("/courses/[slug]/edit", "page");
    revalidatePath(ROUTES.COURSES);
  }
  return result;
}

export async function uploadAssetAction(
  formData: FormData,
): Promise<ActionResult<{ url: string; storage_key: string }>> {
  return apiUpload<{ url: string; storage_key: string }>("/api/upload", formData);
}

// ─── Final test + certificates ───────────────────────────────────────────────

export async function upsertFinalTestAction(
  courseId: string,
  input: {
    questions: FinalTestQuestion[];
    time_limit_minutes: number;
    passing_score_percent: number;
    max_attempts: number;
  },
): Promise<ActionResult> {
  const result = await apiAction("PUT", `/api/courses/${courseId}/final-test`, input);
  if (result.ok) revalidatePath("/courses/[slug]/edit", "page");
  return result;
}

export async function submitFinalTestAttemptAction(
  courseId: string,
  answers: Record<string, unknown>,
): Promise<ActionResult<SubmitFinalTestAttemptResult>> {
  return apiAction<SubmitFinalTestAttemptResult>(
    "POST",
    `/api/courses/${courseId}/final-test/attempt`,
    { answers },
  );
}

export async function upsertCertificateRuleAction(
  courseId: string,
  thresholdPercent: number,
): Promise<ActionResult<CertificateRule>> {
  const result = await apiAction<CertificateRule>(
    "PUT",
    `/api/courses/${courseId}/certificate-rule`,
    { threshold_percent: thresholdPercent },
  );
  if (result.ok) revalidatePath("/courses/[slug]/edit", "page");
  return result;
}
