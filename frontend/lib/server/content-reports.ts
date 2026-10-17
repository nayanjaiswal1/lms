import "server-only";

import { apiGet } from "@/lib/server/api";

export interface ContentReportCounts {
  counts: { pending: number; reviewing: number; removed: number; dismissed: number };
  open: number;
}

// Requires content.moderate; callers gate before calling.
export function getContentReportCounts(): Promise<ContentReportCounts> {
  return apiGet<ContentReportCounts>("/api/content-reports/counts");
}
