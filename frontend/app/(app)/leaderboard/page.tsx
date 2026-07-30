import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Trophy } from "lucide-react";

import { LeaderboardTable } from "@/components/rewards/leaderboard-table";
import { ScopeTabs } from "@/components/rewards/scope-tabs";
import type { LeaderboardScope } from "@/components/rewards/scope-tabs";
import { LeaderboardGroupPicker } from "@/components/cohorts/leaderboard-group-picker";
import { getCurrentUser } from "@/lib/server/auth";
import { getLeaderboard, getMyRank } from "@/lib/server/rewards";
import { getCohortGroups, buildCohortTree } from "@/lib/server/cohorts";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Leaderboard",
  description: "See how you rank against your peers on MindForge.",
};

interface LeaderboardPageProps {
  searchParams: Promise<{
    scope?: string;
    scope_id?: string;
    feature_type?: string;
  }>;
}

const VALID_SCOPES = new Set<LeaderboardScope>(["global", "org", "batch", "group", "course", "feature"]);

function sanitizeScope(raw?: string): LeaderboardScope {
  if (raw && VALID_SCOPES.has(raw as LeaderboardScope)) return raw as LeaderboardScope;
  return "global";
}

export default async function LeaderboardPage({ searchParams }: LeaderboardPageProps) {
  const user = await getCurrentUser();
  if (!user) redirect(ROUTES.LOGIN);

  const params = await searchParams;
  const scope = sanitizeScope(params.scope);
  const scopeId = params.scope_id;
  const featureType = params.feature_type;

  const [leaderboardData, myRankData, cohortGroups] = await Promise.all([
    getLeaderboard(scope, scopeId, featureType, 50, 0),
    getMyRank(scope, scopeId, featureType),
    // Staff-only endpoint (RequireOrgRole admin/instructor/mentor) — students
    // get a 403, so the tree picker simply doesn't render for them below.
    getCohortGroups().catch(() => []),
  ]);

  const entries = leaderboardData?.entries ?? [];
  const cohortTree = buildCohortTree(cohortGroups);
  const activeGroup = scope === "group" ? cohortGroups.find((g) => g.id === scopeId) : undefined;

  // Build the tab list — always show Global + Org; conditionally show Batch/Course/Feature
  // when scope_id is present in the URL (the user navigated here from a context page)
  const tabs = [
    { scope: "global" as LeaderboardScope, label: "Global" },
    { scope: "org" as LeaderboardScope, label: "My Org" },
    ...(scopeId && scope === "batch"
      ? [{ scope: "batch" as LeaderboardScope, label: "This Batch", scopeId }]
      : []),
    ...(activeGroup
      ? [{ scope: "group" as LeaderboardScope, label: activeGroup.name, scopeId: activeGroup.id }]
      : []),
    ...(scopeId && scope === "course"
      ? [{ scope: "course" as LeaderboardScope, label: "This Course", scopeId }]
      : []),
    ...(scopeId && scope === "feature" && featureType === "problems"
      ? [{ scope: "feature" as LeaderboardScope, label: "Problems", scopeId, featureType: "problems" }]
      : []),
    ...(scopeId && scope === "feature" && featureType === "quizzes"
      ? [{ scope: "feature" as LeaderboardScope, label: "Quizzes", scopeId, featureType: "quizzes" }]
      : []),
  ];

  return (
    <main className="page-container">
      <div className="mb-8 flex flex-col gap-2">
        <div className="flex items-center gap-3">
          <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10">
            <Trophy aria-hidden className="h-5 w-5 text-primary" />
          </span>
          <h1>Leaderboard</h1>
        </div>
        <p className="text-muted-foreground">
          Rankings update in real time as learners earn XP.
        </p>
      </div>

      {myRankData && myRankData.rank > 0 && (
        <div className="mb-6 flex items-center gap-4 rounded-xl border border-border bg-primary/10 px-5 py-4">
          <div className="flex flex-col">
            <p className="text-xs text-muted-foreground">Your rank</p>
            <p className="text-2xl font-bold tabular-nums text-primary">#{myRankData.rank}</p>
          </div>
          <div className="h-8 w-px bg-border" />
          <div className="flex flex-col">
            <p className="text-xs text-muted-foreground">Your XP</p>
            <p className="text-2xl font-bold tabular-nums">{myRankData.xp.toLocaleString()}</p>
          </div>
        </div>
      )}

      <div className="mb-6">
        <ScopeTabs
          activeFeatureType={featureType}
          activeScope={scope}
          activeScopeId={scopeId}
          tabs={tabs}
        />
      </div>

      {cohortTree.length > 0 && (
        <div className="card-base mb-6 p-4">
          <h2 className="subsection-title mb-3">Browse by cohort group</h2>
          <LeaderboardGroupPicker allGroups={cohortGroups} roots={cohortTree} selectedId={activeGroup?.id} />
        </div>
      )}

      <LeaderboardTable
        entries={entries}
        myRank={myRankData && myRankData.rank > 0 ? myRankData.rank : undefined}
        myUserID={user.id}
      />
    </main>
  );
}
