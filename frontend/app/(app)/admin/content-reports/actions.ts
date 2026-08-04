"use server";

import { apiAction, type ActionResult } from "@/lib/server/api";

export async function resolveContentReportAction(
  reportId: string,
  status: string,
  resolutionNote: string,
): Promise<ActionResult> {
  return apiAction("PATCH", `/api/content-reports/${reportId}`, {
    status,
    resolution_note: resolutionNote,
  });
}
