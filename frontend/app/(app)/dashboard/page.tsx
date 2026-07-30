import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import {
  BookOpen,
  Calendar,
  ClipboardCheck,
  ArrowRight,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { LeaderboardTable, MyRewardSummary } from "@/components/rewards/leaderboard-table";
import { ScopeTabs } from "@/components/rewards/scope-tabs";
import type { LeaderboardScope } from "@/components/rewards/scope-tabs";
import { CourseCard } from "@/components/courses/course-card";
import { AIConnectorNudge } from "@/components/settings/ai-connector-nudge";
import ROUTES from "@/lib/routes";
import { getCurrentUser } from "@/lib/server/auth";
import { getEnrollments, getCourseProgress } from "@/lib/server/courses";
import { getMyAssessments } from "@/lib/assessments/server";
import { getMyRewardProfile, getLeaderboard, getMyRank } from "@/lib/server/rewards";
import { listEventsAction } from "@/lib/server/calendar";
import { getMyBatches } from "@/lib/server/batches";
import { apiGet } from "@/lib/server/api";
import type { Enrollment, CourseProgressSummary } from "@/lib/server/courses";
import type { AssignedAssessment } from "@/lib/assessments/types";
import type { CalendarEvent } from "@/lib/calendar/types";

export const metadata: Metadata = {
  title: "Dashboard",
  description: "Your MindForge learning dashboard.",
};

interface EnrolledCourseWithProgress {
  enrollment: Enrollment;
  progress: CourseProgressSummary | null;
}

// Most recent module_progress.updated_at is the last time the student actually
// touched the course; enrolled_at is the only fallback for a course with no
// progress rows yet.
function lastActivity({ enrollment, progress }: EnrolledCourseWithProgress): number {
  const moduleTimestamps = progress?.modules.map((m) => new Date(m.updated_at).getTime()) ?? [];
  return Math.max(new Date(enrollment.enrolled_at).getTime(), ...moduleTimestamps);
}

async function fetchEnrolledCoursesWithProgress(): Promise<EnrolledCourseWithProgress[]> {
  try {
    const enrollments = await getEnrollments();

    const withProgress = await Promise.all(
      enrollments.map(async (enrollment) => {
        try {
          const progress = await getCourseProgress(enrollment.course_id);
          return { enrollment, progress };
        } catch {
          return { enrollment, progress: null };
        }
      }),
    );

    return withProgress.sort((a, b) => lastActivity(b) - lastActivity(a)).slice(0, 3);
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

const DASHBOARD_LEADERBOARD_SIZE = 5;

async function fetchLeaderboardPreview(scope: LeaderboardScope, scopeId?: string) {
  const [leaderboard, myRank] = await Promise.all([
    getLeaderboard(scope, scopeId, undefined, DASHBOARD_LEADERBOARD_SIZE, 0),
    getMyRank(scope, scopeId),
  ]);

  return {
    entries: leaderboard?.entries ?? [],
    myRank: myRank && myRank.rank > 0 ? myRank.rank : undefined,
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

interface DashboardPageProps {
  searchParams: Promise<{ scope?: string; scope_id?: string }>;
}

export default async function DashboardPage({ searchParams }: DashboardPageProps) {
  const user = await getCurrentUser();
  if (!user) redirect(ROUTES.LOGIN);

  const firstName = user.name.split(" ")[0];
  const params = await searchParams;

  const [coursesWithProgress, upcomingItems, rewardProfile, myBatches, hasAIConnection] = await Promise.all([
    fetchEnrolledCoursesWithProgress(),
    fetchUpcomingItems(),
    getMyRewardProfile(),
    getMyBatches(),
    apiGet<{ id: string }[] | null>("/api/mcp-connections").then((c) => Boolean(c?.length)).catch(() => false),
  ]);

  // "Your standing" scope: global by default, one of the user's batches, or —
  // if a batch belongs to a cohort group (Class/Section hierarchy above
  // batches) — that group, rolling up every batch under it. Folds what used
  // to be a separate "Your batch" box into a filter here.
  const activeBatch = params.scope === "batch" ? myBatches.find((b) => b.id === params.scope_id) : undefined;
  const activeGroupBatch = params.scope === "group" ? myBatches.find((b) => b.cohort_group_id === params.scope_id) : undefined;
  const standingScope: LeaderboardScope = activeBatch ? "batch" : activeGroupBatch ? "group" : "global";
  const standingScopeId = activeBatch?.id ?? activeGroupBatch?.cohort_group_id ?? undefined;
  const leaderboardPreview = await fetchLeaderboardPreview(standingScope, standingScopeId);

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
    <main className="page-container">
      <div className="mb-8 flex flex-col gap-2">
        <h1>Welcome back, {firstName}</h1>
        <p className="text-muted-foreground">Here&apos;s your learning overview.</p>
      </div>

      <AIConnectorNudge hasConnection={hasAIConnection} />

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-3">
        {/* Main column */}
        <div className="lg:col-span-2">
          {/* Enrolled courses */}
          <section className="mb-8">
            <div className="mb-4 flex items-center justify-between gap-4">
              <h2 className="section-title">Your courses</h2>
              <Link
                className="flex items-center gap-1 text-sm text-primary hover:underline"
                href={ROUTES.COURSES}
              >
                View all <ArrowRight aria-hidden className="h-3.5 w-3.5" />
              </Link>
            </div>

            {coursesWithProgress.length === 0 ? (
              <div className="empty-state">
                <BookOpen aria-hidden className="h-10 w-10 text-muted-foreground" />
                <p className="text-muted-foreground">
                  You haven&apos;t enrolled in any courses yet.
                </p>
                <Button asChild size="sm" variant="outline">
                  <Link href={ROUTES.COURSES}>Browse courses</Link>
                </Button>
              </div>
            ) : (
              <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                {coursesWithProgress.map(({ enrollment, progress }) => (
                  <CourseCard
                    enrolled
                    course={enrollment.course}
                    href={ROUTES.courseLearn(enrollment.course.slug)}
                    key={enrollment.id}
                    progressPct={Math.round(progress?.pct ?? 0)}
                  />
                ))}
              </div>
            )}
          </section>

          {/* Upcoming — assessments due and calendar events, merged into one timeline */}
          <section>
            <div className="mb-4 flex items-center justify-between gap-4">
              <h2 className="section-title">Upcoming</h2>
              <Link
                className="flex items-center gap-1 text-sm text-primary hover:underline"
                href={ROUTES.CALENDAR}
              >
                Calendar <ArrowRight aria-hidden className="h-3.5 w-3.5" />
              </Link>
            </div>

            {upcomingItems.length === 0 ? (
              <div className="empty-state">
                <Calendar aria-hidden className="h-10 w-10 text-muted-foreground" />
                <p className="text-muted-foreground">Nothing due or on your calendar right now.</p>
              </div>
            ) : (
              <div className="flex flex-col gap-3">
                {upcomingItems.map((item) =>
                  item.kind === "assessment" ? (
                    <AssessmentRow assessment={item.assessment} key={`a-${item.assessment.id}`} />
                  ) : (
                    <UpcomingEventRow event={item.event} key={`e-${item.event.id}`} />
                  ),
                )}
              </div>
            )}
          </section>
        </div>

        {/* Right rail */}
        <aside className="flex flex-col gap-8 lg:col-span-1">
          {/* Your standing — XP/achievements, batch, and leaderboard rank, one card.
              Batch used to be its own box; it's now a scope filter here instead,
              since "which leaderboard" and "which batch" are the same question. */}
          {(rewardProfile || leaderboardPreview.entries.length > 0 || myBatches.length > 0) && (
            <section className="card-base flex flex-col gap-4 p-5">
              <div className="flex items-center justify-between gap-4">
                <h2 className="subsection-title">Your standing</h2>
                <Link
                  className="flex items-center gap-1 text-sm text-primary hover:underline"
                  href={standingHref}
                >
                  View all <ArrowRight aria-hidden className="h-3.5 w-3.5" />
                </Link>
              </div>

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
                  myUserID={user.id}
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
          )}
        </aside>
      </div>
    </main>
  );
}

// ─── Sub-components ────────────────────────────────────────────────────────────

interface UpcomingEventRowProps {
  event: CalendarEvent;
}

function UpcomingEventRow({ event }: UpcomingEventRowProps) {
  return (
    <Link
      className="card-interactive flex items-center gap-3 p-3"
      href={`${ROUTES.CALENDAR}?event=${event.id}`}
    >
      <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary/10">
        <Calendar aria-hidden className="h-4 w-4 text-primary" />
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium">{event.title}</p>
        <p className="text-xs text-muted-foreground">{formatEventTime(event.starts_at, event.all_day)}</p>
      </div>
    </Link>
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
  const href = assessmentHref(assessment);

  const content = (
    <>
      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-primary/10">
        <ClipboardCheck aria-hidden className="h-5 w-5 text-primary" />
      </span>

      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-semibold">{assessment.title}</p>
        <p className={`text-xs ${isOverdue ? "text-destructive" : "text-muted-foreground"}`}>
          {dueDateLabel}
          {attemptsLeft > 0 && attemptsLeft < assessment.max_attempts && (
            <span className="ml-2 text-muted-foreground">
              · {attemptsLeft} attempt{attemptsLeft !== 1 ? "s" : ""} left
            </span>
          )}
        </p>
      </div>

      <Button asChild className="pointer-events-none shrink-0" size="icon" variant="ghost">
        <span aria-hidden>
          <ArrowRight className="h-4 w-4" />
        </span>
      </Button>
    </>
  );

  if (!href) {
    return (
      <div className="card-base flex items-center gap-4 p-4 opacity-60">
        {content}
      </div>
    );
  }

  return (
    <Link className="card-interactive flex items-center gap-4 p-4" href={href}>
      {content}
    </Link>
  );
}
