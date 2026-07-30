import type { Metadata } from "next";
import { NavHubGrid } from "@/components/shared/nav-hub-grid";
import ROUTES from "@/lib/routes";
import { getEnrollments, type Enrollment } from "@/lib/server/courses";
import { listRoadmaps, type Roadmap } from "@/lib/server/roadmap";
import { listPrepPlans, type PrepPlan } from "@/lib/server/interview-prep";
import { getMyAssessments } from "@/lib/assessments/server";
import type { AssignedAssessment } from "@/lib/assessments/types";
import { getMyHighlights, type Highlight } from "@/lib/server/highlights";
import { getDueCards, type DueCardsResponse } from "@/lib/server/srs";
import { getUserSheets, type UserSheetSummary } from "@/lib/server/sheets";
import { getWikiSpaces, type WikiSpace } from "@/lib/server/wiki";
import { listPosts, type Post } from "@/lib/server/interview-exp";

export const metadata: Metadata = { title: "Learn" };

// Each source backs one Learn hub card. A viewer without access to that
// feature gets a rejected fetch (403/404) here, not a broken page — so every
// source falls back independently instead of failing the whole hub.
async function getHubStats(): Promise<Record<string, string>> {
  const [enrollments, roadmaps, prepPlans, assessments, highlights, dueCards, sheets, wikiSpaces, expPosts] =
    await Promise.all([
      getEnrollments().catch((): Enrollment[] => []),
      listRoadmaps().catch((): Roadmap[] => []),
      listPrepPlans().catch((): PrepPlan[] => []),
      getMyAssessments().catch((): AssignedAssessment[] => []),
      getMyHighlights(true).catch((): Highlight[] => []),
      getDueCards().catch((): DueCardsResponse => ({ cards: [], total: 0 })),
      getUserSheets().catch((): UserSheetSummary[] => []),
      getWikiSpaces().catch((): WikiSpace[] => []),
      listPosts({}).catch((): Post[] => []),
    ]);

  const activeRoadmap = roadmaps.find((r) => r.status === "active") ?? roadmaps[0];
  const pendingAssessments = assessments.filter(
    (a) => a.status !== "archived" && a.status !== "completed" && !(a.attempts_used >= a.max_attempts && a.best_passed),
  );
  const sheetProgress = sheets.reduce(
    (acc, s) => ({ solved: acc.solved + s.solved_count, total: acc.total + s.item_count }),
    { solved: 0, total: 0 },
  );

  return {
    [ROUTES.COURSES]: enrollments.length ? `${enrollments.length} enrolled` : "Browse courses",
    [ROUTES.ROADMAP]: activeRoadmap
      ? `${activeRoadmap.completed_count}/${activeRoadmap.module_count} steps done`
      : "Start a roadmap",
    [ROUTES.INTERVIEW_PREP]: prepPlans.length ? `${prepPlans.length} plan${prepPlans.length === 1 ? "" : "s"}` : "No plans yet",
    [ROUTES.ASSESSMENTS]: pendingAssessments.length ? `${pendingAssessments.length} pending` : "All caught up",
    [ROUTES.HIGHLIGHTS]: highlights.length ? `${highlights.length} saved` : "Nothing saved yet",
    [ROUTES.REVIEW]: dueCards.total ? `${dueCards.total} due` : "Nothing due",
    [ROUTES.SHEETS]: sheetProgress.total ? `${sheetProgress.solved}/${sheetProgress.total} solved` : "No sheets yet",
    [ROUTES.WIKI]: wikiSpaces.length ? `${wikiSpaces.length} space${wikiSpaces.length === 1 ? "" : "s"}` : "No spaces yet",
    [ROUTES.INTERVIEW_EXP]: expPosts.length ? `${expPosts.length} posts` : "No posts yet",
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
