"use server";

import { apiAction, type ActionResult } from "@/lib/server/api";

export async function reportContentAction(
  contentType: "wiki_page" | "course_module",
  contentId: string,
  reason: string,
  description: string,
): Promise<ActionResult> {
  return apiAction("POST", "/api/content-reports", {
    content_type: contentType,
    content_id: contentId,
    reason,
    description,
  });
}
