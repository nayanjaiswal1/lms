import "server-only";

import { apiGet } from "@/lib/server/api";

export type ActivityKind =
  | "module_completed"
  | "course_completed"
  | "quiz_attempt"
  | "reflection"
  | "sheet_problem_solved"
  | "lab_completed"
  | "card_reviewed";

export interface ActivityEntry {
  key: string;
  kind: ActivityKind;
  occurred_at: string;
  day: string; // YYYY-MM-DD
  title: string;
  summary?: string;
  ref_id?: string;
  ref_type?: string;
  ref_slug?: string;
}

export interface ActivityPage {
  entries: ActivityEntry[];
  next_cursor?: string;
}

export async function getActivity(opts?: { limit?: number; cursor?: string }): Promise<ActivityPage> {
  const params = new URLSearchParams();
  if (opts?.limit) params.set("limit", String(opts.limit));
  if (opts?.cursor) params.set("cursor", opts.cursor);

  const qs = params.toString();
  const data = await apiGet<ActivityPage>(`/api/activity${qs ? `?${qs}` : ""}`);
  return { entries: data.entries ?? [], next_cursor: data.next_cursor };
}
