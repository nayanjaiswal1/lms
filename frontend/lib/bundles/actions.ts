"use server";

import { revalidatePath } from "next/cache";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import type { Bundle, BundleDetail } from "@/lib/server/bundles";
import ROUTES from "@/lib/routes";

interface BundleInput {
  title: string;
  description: string | null;
  status: "draft" | "published";
}

interface BundleEnrollResult {
  enrolled_course_ids: string[];
  requires_purchase_course_ids: string[];
}

export async function createBundleAction(input: BundleInput): Promise<ActionResult<Bundle>> {
  const result = await apiAction<Bundle>("POST", "/api/bundles", input);
  if (result.ok) revalidatePath(ROUTES.COURSES);
  return result;
}

// Saves metadata and the ordered course list together — the editor has one
// Save button, so both writes happen on it.
export async function saveBundleAction(
  bundleID: string,
  input: BundleInput,
  courseIDs: string[],
): Promise<ActionResult<BundleDetail>> {
  const meta = await apiAction<Bundle>("PATCH", `/api/bundles/${bundleID}`, input);
  if (!meta.ok || !meta.data) return { error: meta.error, fieldErrors: meta.fieldErrors };
  const result = await apiAction<BundleDetail>("PUT", `/api/bundles/${bundleID}/courses`, { course_ids: courseIDs });
  if (result.ok) {
    revalidatePath(ROUTES.COURSES);
    revalidatePath(ROUTES.bundle(meta.data.slug));
  }
  return result;
}

export async function deleteBundleAction(bundleID: string): Promise<ActionResult> {
  const result = await apiAction("DELETE", `/api/bundles/${bundleID}`);
  if (result.ok) revalidatePath(ROUTES.COURSES);
  return result;
}

export async function enrollInBundleAction(bundleID: string, slug: string): Promise<ActionResult<BundleEnrollResult>> {
  const result = await apiAction<BundleEnrollResult>("POST", `/api/bundles/${bundleID}/enroll`);
  if (result.ok) {
    revalidatePath(ROUTES.bundle(slug));
    revalidatePath(ROUTES.COURSES);
  }
  return result;
}
