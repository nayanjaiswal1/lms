import { apiGet } from "@/lib/server/api";

// Mirrors backend/internal/learnhub/models.go Stats — one cheap count per
// Learn hub card, computed server-side with COUNT(*)/SUM() queries instead
// of 9 separate full-list fetches.
export interface HubStats {
  enrollment_count: number;
  has_roadmap: boolean;
  roadmap_module_count: number;
  roadmap_completed_count: number;
  prep_plan_count: number;
  pending_assessment_count: number;
  saved_highlight_count: number;
  due_card_count: number;
  sheet_total_count: number;
  sheet_solved_count: number;
  wiki_space_count: number;
  interview_exp_post_count: number;
}

export async function getLearnHubStats(): Promise<HubStats> {
  return apiGet<HubStats>("/api/learn/hub-stats");
}
