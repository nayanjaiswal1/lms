import {
  BookOpen,
  Calendar,
  ClipboardCheck,
} from "lucide-react";

import { LeaderboardTable, MyRewardSummary } from "@/components/rewards/leaderboard-table";
import { ScopeTabs } from "@/components/rewards/scope-tabs";
import type { LeaderboardScope } from "@/components/rewards/scope-tabs";
import { CourseCard } from "@/components/courses/course-card";
import { AIConnectorNudge } from "@/components/settings/ai-connector-nudge";
import { DashboardReviewWidget } from "@/components/review/dashboard-review-widget";
import { DashboardEmptyState } from "./_components/empty-state";
import { DashboardSectionHeader } from "./_components/section-header";
import { DashboardUpcomingRow } from "./_components/upcoming-row";
import ROUTES from "@/lib/routes";
import { getEnrollments } from "@/lib/server/courses";
import { getMyAssessments } from "@/lib/assessments/server";
import { getMyRewardProfile, getLeaderboard } from "@/lib/server/rewards";
import { listEventsAction } from "@/lib/server/calendar";
import { getMyBatches } from "@/lib/server/batches";
import { getDueCards } from "@/lib/server/srs";
import type { SRSCard } from "@/lib/server/srs";
import { apiGet } from "@/lib/server/api";
import type { Enrollment } from "@/lib/server/courses";
import type { AssignedAssessment } from "@/lib/assessments/types";
import type { CalendarEvent } from "@/lib/calendar/types";

// progress.last_activity_at (the most recent module_progress.updated_at,
// joined server-side by GET /api/enrollments/me) is the last time the
// student actually touched the course; enrolled_at is the only fallback for
// a course with no progress rows yet.
function lastActivity(enrollment: Enrollment): number {
  const lastTouched = enrollment.progress.last_activity_at
    ? new Date(enrollment.progress.last_activity_at).getTime()
    : 0;
  return Math.max(new Date(enrollment.enrolled_at).getTime(), lastTouched);
}

async function fetchEnrolledCoursesWithProgress(): Promise<Enrollment[]> {
  try {
    const enrollments = await getEnrollments();
    return [...enrollments].sort((a, b) => lastActivity(b) - lastActivity(a)).slice(0, 3);
  } catch {
    return [];
  }
}

async function fetchUpcomingAssessments(): Promise<AssignedAssessment[]> {
  try {
    const assessments = await getMyAssessments();

    const upcoming = assessments
      .filter((a) => {
        if (a.status === "archived" || a.status === "completed") return false;
        if (a.attempts_used >= a.max_attempts && a.best_passed) return false;
        return true;
      })
      .sort((a, b) => {
        if (!a.ends_at && !b.ends_at) return 0;
        if (!a.ends_at) return 1;
        if (!b.ends_at) return -1;
        return new Date(a.ends_at).getTime() - new Date(b.ends_at).getTime();
      })
      .slice(0, 3);

    return upcoming;
  } catch {
    return [];
  }
}

const UPCOMING_EVENTS_WINDOW_DAYS = 7;
const UPCOMING_EVENTS_LIMIT = 4;

// Real calendar_events only (mentor sessions, live classes, deadlines,
// custom) — assessment due-windows are merged in separately by
// fetchUpcomingItems, and listEventsAction merges them in as virtual
// entries too, so they're excluded here to avoid showing twice.
async function fetchUpcomingEvents(): Promise<CalendarEvent[]> {
  const from = new Date();
  const to = new Date(from.getTime() + UPCOMING_EVENTS_WINDOW_DAYS * 24 * 60 * 60 * 1000);
  const result = await listEventsAction(from.toISOString(), to.toISOString());
  if (!result.ok || !result.data) return [];

  return result.data
    .filter((e) => e.status === "scheduled" && !e.is_virtual)
    .sort((a, b) => new Date(a.starts_at).getTime() - new Date(b.starts_at).getTime())
    .slice(0, UPCOMING_EVENTS_LIMIT);
}

type UpcomingItem =
  | { kind: "assessment"; sortTime: number; assessment: AssignedAssessment }
  | { kind: "event"; sortTime: number; event: CalendarEvent };

const UPCOMING_ITEMS_LIMIT = 5;

// One merged, date-sorted timeline instead of two separate "upcoming"
// sections — assessments and calendar events were previously split across
// the main column and the right rail even though both answer "what's next".
async function fetchUpcomingItems(): Promise<UpcomingItem[]> {
  const [assessments, events] = await Promise.all([fetchUpcomingAssessments(), fetchUpcomingEvents()]);

  const items: UpcomingItem[] = [
    ...assessments.map((assessment) => ({
      kind: "assessment" as const,
      sortTime: assessment.ends_at ? new Date(assessment.ends_at).getTime() : Infinity,
      assessment,
    })),
    ...events.map((event) => ({
      kind: "event" as const,
      sortTime: new Date(event.starts_at).getTime(),
      event,
    })),
  ];

  return items.sort((a, b) => a.sortTime - b.sortTime).slice(0, UPCOMING_ITEMS_LIMIT);
}

// null (not an empty array) means the feature/permission isn't there for this
// user — getDueCards throws in that case, same as the other server-only
// fetches above, so we just hide the widget instead of replicating nav.ts's
// client-side gating logic server-side.
async function fetchDueCards(): Promise<SRSCard[] | null> {
  try {
    return (await getDueCards()).cards;
  } catch {
    return null;
  }
}

const DASHBOARD_LEADERBOARD_SIZE = 5;

// getLeaderboard's response already embeds the caller's own rank (`me`) —
// no separate getMyRank call needed just to show it alongside the preview.
async function fetchLeaderboardPreview(scope: LeaderboardScope, scopeId?: string) {
  const leaderboard = await getLeaderboard(scope, scopeId, undefined, DASHBOARD_LEADERBOARD_SIZE, 0);

  return {
    entries: leaderboard?.entries ?? [],
    myRank: leaderboard?.me && leaderboard.me.rank > 0 ? leaderboard.me.rank : undefined,
  };
}

function startOfDay(d: Date): Date {
  const copy = new Date(d);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

function formatEventTime(startsAt: string, allDay: boolean): string {
  const date = new Date(startsAt);
  const diffDays = Math.round((startOfDay(date).getTime() - startOfDay(new Date()).getTime()) / 86_400_000);
  const dayLabel =
    diffDays === 0
      ? "Today"
      : diffDays === 1
        ? "Tomorrow"
        : date.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" });

  if (allDay) return dayLabel;
  return `${dayLabel} · ${date.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })}`;
}

function formatBatchWindow(startsAt: string | null, endsAt: string | null): string {
  const fmt = (iso: string) => new Date(iso).toLocaleDateString("en-US", { month: "short", day: "numeric" });
  if (!endsAt) return startsAt ? `Started ${fmt(startsAt)}` : "No dates set";

  const diffDays = Math.ceil((new Date(endsAt).getTime() - Date.now()) / (1000 * 60 * 60 * 24));
  if (diffDays < 0) return `Ended ${fmt(endsAt)}`;
  if (diffDays === 0) return "Ends today";
  if (diffDays === 1) return "Ends tomorrow";
  if (diffDays <= 14) return `Ends in ${diffDays} days`;
  return `Ends ${fmt(endsAt)}`;
}

function formatDueDate(endsAt: string | null): string {
  if (!endsAt) return "No due date";
  const date = new Date(endsAt);
  const now = new Date();
  const diffMs = date.getTime() - now.getTime();
  const diffDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

  if (diffDays < 0) return "Overdue";
  if (diffDays === 0) return "Due today";
  if (diffDays === 1) return "Due tomorrow";
  if (diffDays <= 7) return `Due in ${diffDays} days`;

  return `Due ${date.toLocaleDateString("en-US", { month: "short", day: "numeric" })}`;
}

// ─── Streamed sections ─────────────────────────────────────────────────────────
// Each section fetches its own data behind its own <Suspense> in page.tsx, so
// the dashboard paints as soon as the header is ready and every section fills
// in independently instead of all waiting on the slowest backend call.

export async function AIConnectorNudgeSection() {
  const hasConnection = await apiGet<{ id: string }[] | null>("/api/mcp-connections")
    .then((c) => Boolean(c?.length))
    .catch(() => false);
  return <AIConnectorNudge hasConnection={hasConnection} />;
}

export async function CoursesSection() {
  const coursesWithProgress = await fetchEnrolledCoursesWithProgress();

  if (coursesWithProgress.length === 0) {
    return (
      <DashboardEmptyState
        action={{ href: ROUTES.COURSES, label: "Browse courses" }}
        icon={BookOpen}
        message="You haven't enrolled in any courses yet."
      />
    );
  }

  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
      {coursesWithProgress.map((enrollment) => (
        <CourseCard
          enrolled
          course={enrollment.course}
          href={ROUTES.courseLearn(enrollment.course.slug)}
          key={enrollment.id}
          progressPct={Math.round(enrollment.progress.pct)}
        />
      ))}
    </div>
  );
}

export async function UpcomingSection() {
  const upcomingItems = await fetchUpcomingItems();

  if (upcomingItems.length === 0) {
    return (
      <DashboardEmptyState
        icon={Calendar}
        message="Nothing due or on your calendar right now."
      />
    );
  }

  return (
    <div className="flex flex-col gap-3">
      {upcomingItems.map((item) =>
        item.kind === "assessment" ? (
          <AssessmentRow assessment={item.assessment} key={`a-${item.assessment.id}`} />
        ) : (
          <UpcomingEventRow event={item.event} key={`e-${item.event.id}`} />
        ),
      )}
    </div>
  );
}

export async function ReviewSection() {
  const dueCards = await fetchDueCards();
  return dueCards !== null ? <DashboardReviewWidget cards={dueCards} /> : null;
}

interface StandingSectionProps {
  userId: string;
  scope?: string;
  scopeId?: string;
}

export async function StandingSection({ userId, scope, scopeId }: StandingSectionProps) {
  const [rewardProfile, myBatches] = await Promise.all([getMyRewardProfile(), getMyBatches()]);

  // "Your standing" scope: global by default, one of the user's batches, or —
  // if a batch belongs to a cohort group (Class/Section hierarchy above
  // batches) — that group, rolling up every batch under it. Folds what used
  // to be a separate "Your batch" box into a filter here.
  const activeBatch = scope === "batch" ? myBatches.find((b) => b.id === scopeId) : undefined;
  const activeGroupBatch = scope === "group" ? myBatches.find((b) => b.cohort_group_id === scopeId) : undefined;
  const standingScope: LeaderboardScope = activeBatch ? "batch" : activeGroupBatch ? "group" : "global";
  const standingScopeId = activeBatch?.id ?? activeGroupBatch?.cohort_group_id ?? undefined;
  const leaderboardPreview = await fetchLeaderboardPreview(standingScope, standingScopeId);

  if (!rewardProfile && leaderboardPreview.entries.length === 0 && myBatches.length === 0) return null;

  const seenGroupIds = new Set<string>();
  const groupTabs = myBatches.flatMap((b) => {
    if (!b.cohort_group_id || seenGroupIds.has(b.cohort_group_id)) return [];
    seenGroupIds.add(b.cohort_group_id);
    return [{ scope: "group" as const, label: b.cohort_group_name ?? "Group", scopeId: b.cohort_group_id }];
  });
  const standingTabs = [
    { scope: "global" as const, label: "Global" },
    ...myBatches.map((b) => ({ scope: "batch" as const, label: b.name, scopeId: b.id })),
    ...groupTabs,
  ];
  const standingHref = activeBatch
    ? `${ROUTES.LEADERBOARD}?scope=batch&scope_id=${activeBatch.id}`
    : activeGroupBatch?.cohort_group_id
      ? `${ROUTES.LEADERBOARD}?scope=group&scope_id=${activeGroupBatch.cohort_group_id}`
      : ROUTES.LEADERBOARD;

  return (
    <section className="card-base flex flex-col gap-4 p-5">
      <DashboardSectionHeader
        link={{ href: standingHref, label: "View all" }}
        size="subsection"
        title="Your standing"
      />

      {myBatches.length > 0 && (
        <ScopeTabs activeScope={standingScope} activeScopeId={standingScopeId} tabs={standingTabs} />
      )}

      {activeBatch && (
        <p className="text-xs text-muted-foreground">{formatBatchWindow(activeBatch.starts_at, activeBatch.ends_at)}</p>
      )}

      {/* Progress-to-next-level and achievements render inline inside your
          own highlighted row in the list below — no separate block needed. */}
      {leaderboardPreview.entries.length > 0 ? (
        <LeaderboardTable
          entries={leaderboardPreview.entries}
          myAchievements={rewardProfile?.achievements}
          myProgressPct={rewardProfile && rewardProfile.level.max_xp !== -1 ? rewardProfile.level.progress_pct : undefined}
          myRank={leaderboardPreview.myRank}
          myUserID={userId}
        />
      ) : (
        rewardProfile && (
          <MyRewardSummary
            achievements={rewardProfile.achievements}
            progressPct={rewardProfile.level.max_xp !== -1 ? rewardProfile.level.progress_pct : undefined}
          />
        )
      )}
    </section>
  );
}

// ─── Sub-components ────────────────────────────────────────────────────────────

interface UpcomingEventRowProps {
  event: CalendarEvent;
}

function UpcomingEventRow({ event }: UpcomingEventRowProps) {
  return (
    <DashboardUpcomingRow
      href={`${ROUTES.CALENDAR}?event=${event.id}`}
      icon={Calendar}
      subtitle={formatEventTime(event.starts_at, event.all_day)}
      title={event.title}
    />
  );
}

interface AssessmentRowProps {
  assessment: AssignedAssessment;
}

function assessmentHref(assessment: AssignedAssessment): string | null {
  if (assessment.active_attempt_id) return ROUTES.assessmentTake(assessment.id);
  if (assessment.evaluating_attempt_id) return ROUTES.assessmentResult(assessment.evaluating_attempt_id);
  if (assessment.attempts_used < assessment.max_attempts) return ROUTES.assessmentTake(assessment.id);
  return null;
}

function AssessmentRow({ assessment }: AssessmentRowProps) {
  const dueDateLabel = formatDueDate(assessment.ends_at);
  const isOverdue = assessment.ends_at && new Date(assessment.ends_at) < new Date();
  const attemptsLeft = assessment.max_attempts - assessment.attempts_used;

  return (
    <DashboardUpcomingRow
      href={assessmentHref(assessment)}
      icon={ClipboardCheck}
      subtitle={
        <>
          {dueDateLabel}
          {attemptsLeft > 0 && attemptsLeft < assessment.max_attempts && (
            <span className="ml-2 text-muted-foreground">
              · {attemptsLeft} attempt{attemptsLeft !== 1 ? "s" : ""} left
            </span>
          )}
        </>
      }
      subtitleTone={isOverdue ? "destructive" : "muted"}
      title={assessment.title}
    />
  );
}
