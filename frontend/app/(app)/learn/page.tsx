import type { Metadata } from "next";
import { NavHubGrid } from "@/components/shared/nav-hub-grid";
import ROUTES from "@/lib/routes";
import { getLearnHubStats, type HubStats } from "@/lib/server/learn-hub";

export const metadata: Metadata = { title: "Learn" };

// One aggregator call backs every Learn hub card (see
// backend/internal/learnhub) instead of 9 separate full-list fetches across
// 9 domains. A viewer without access to a feature still gets a whole-hub
// fallback (all cards show their empty state) rather than a broken page —
// same "never fail the whole hub" intent as before, just one failure surface
// instead of nine independent ones.
async function getHubStats(): Promise<Record<string, string>> {
  const stats = await getLearnHubStats().catch(
    (): HubStats => ({
      enrollment_count: 0,
      has_roadmap: false,
      roadmap_module_count: 0,
      roadmap_completed_count: 0,
      prep_plan_count: 0,
      pending_assessment_count: 0,
      saved_highlight_count: 0,
      due_card_count: 0,
      sheet_total_count: 0,
      sheet_solved_count: 0,
      wiki_space_count: 0,
      interview_exp_post_count: 0,
    }),
  );

  return {
    [ROUTES.COURSES]: stats.enrollment_count ? `${stats.enrollment_count} enrolled` : "Browse courses",
    [ROUTES.ROADMAP]: stats.has_roadmap
      ? `${stats.roadmap_completed_count}/${stats.roadmap_module_count} steps done`
      : "Start a roadmap",
    [ROUTES.INTERVIEW_PREP]: stats.prep_plan_count
      ? `${stats.prep_plan_count} plan${stats.prep_plan_count === 1 ? "" : "s"}`
      : "No plans yet",
    [ROUTES.ASSESSMENTS]: stats.pending_assessment_count ? `${stats.pending_assessment_count} pending` : "All caught up",
    [ROUTES.HIGHLIGHTS]: stats.saved_highlight_count ? `${stats.saved_highlight_count} saved` : "Nothing saved yet",
    [ROUTES.REVIEW]: stats.due_card_count ? `${stats.due_card_count} due` : "Nothing due",
    [ROUTES.SHEETS]: stats.sheet_total_count
      ? `${stats.sheet_solved_count}/${stats.sheet_total_count} solved`
      : "No sheets yet",
    [ROUTES.WIKI]: stats.wiki_space_count ? `${stats.wiki_space_count} space${stats.wiki_space_count === 1 ? "" : "s"}` : "No spaces yet",
    [ROUTES.INTERVIEW_EXP]: stats.interview_exp_post_count ? `${stats.interview_exp_post_count} posts` : "No posts yet",
  };
}

export default async function LearnHubPage() {
  const stats = await getHubStats();

  return (
    <main className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">Learn</h1>
          <p className="text-sm text-muted-foreground">Courses, assessments, practice, and every learning tool in one place.</p>
        </div>
      </div>

      <NavHubGrid catalogue="learn" stats={stats} />
    </main>
  );
}
