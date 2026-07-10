import type { Metadata } from "next";
import Link from "next/link";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import {
  BookOpen,
  Calendar,
  ClipboardCheck,
  ArrowRight,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { XPProgressBar } from "@/components/rewards/xp-progress-bar";
import { LeaderboardTable } from "@/components/rewards/leaderboard-table";
import { CourseCard } from "@/components/courses/course-card";
import ROUTES from "@/lib/routes";
import { getEnrollments, getCourseProgress } from "@/lib/server/courses";
import { getMyAssessments } from "@/lib/assessments/server";
import { getMyRewardProfile, getLeaderboard, getMyRank } from "@/lib/server/rewards";
import { listEventsAction } from "@/lib/server/calendar";
import { getMyBatches } from "@/lib/server/batches";
import type { Enrollment, CourseProgressSummary } from "@/lib/server/courses";
import type { AssignedAssessment } from "@/lib/assessments/types";
import type { CalendarEvent } from "@/lib/calendar/types";
import type { MyBatch } from "@/lib/server/batches";

export const metadata: Metadata = {
  title: "Dashboard",
  description: "Your MindForge learning dashboard.",
};

interface User {
  id: string;
  name: string;
  email: string;
  avatar_url: string;
}

async function getCurrentUser(): Promise<User | null> {
  const cookieStore = await cookies();
  const accessToken = cookieStore.get("access_token")?.value;
  if (!accessToken) return null;

  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) return null;

  try {
    const response = await fetch(`${apiUrl}/api/auth/me`, {
      headers: { Cookie: `access_token=${accessToken}` },
      cache: "no-store",
    });
    if (!response.ok) return null;
    const body: { data: { user: User } } = await response.json();
    return body.data.user;
  } catch {
    return null;
  }
}

interface EnrolledCourseWithProgress {
  enrollment: Enrollment;
  progress: CourseProgressSummary | null;
}

async function fetchEnrolledCoursesWithProgress(): Promise<EnrolledCourseWithProgress[]> {
  try {
    const enrollments = await getEnrollments();
    const top = enrollments.slice(0, 3);

    const withProgress = await Promise.all(
      top.map(async (enrollment) => {
        try {
          const progress = await getCourseProgress(enrollment.course_id);
          return { enrollment, progress };
        } catch {
          return { enrollment, progress: null };
        }
      }),
    );

    return withProgress;
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
// custom) — assessment due-windows already have their own "Upcoming
// assessments" section above, and listEventsAction merges them in as
// virtual entries too, so they're excluded here to avoid showing twice.
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

const DASHBOARD_LEADERBOARD_SIZE = 5;

async function fetchLeaderboardPreview() {
  const [leaderboard, myRank] = await Promise.all([
    getLeaderboard("global", undefined, undefined, DASHBOARD_LEADERBOARD_SIZE, 0),
    getMyRank("global"),
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

export default async function DashboardPage() {
  const user = await getCurrentUser();
  if (!user) redirect(ROUTES.LOGIN);

  const firstName = user.name.split(" ")[0];

  const [coursesWithProgress, upcomingAssessments, upcomingEvents, rewardProfile, leaderboardPreview, myBatches] = await Promise.all([
    fetchEnrolledCoursesWithProgress(),
    fetchUpcomingAssessments(),
    fetchUpcomingEvents(),
    getMyRewardProfile(),
    fetchLeaderboardPreview(),
    getMyBatches(),
  ]);

  return (
    <main className="page-container py-10">
      <div className="mb-8 flex flex-col gap-2">
        <h1>Welcome back, {firstName}</h1>
        <p className="text-muted-foreground">Here&apos;s your learning overview.</p>
      </div>

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
              <div className="grid gap-4 sm:grid-cols-2">
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

          {/* Upcoming assessments */}
          <section>
            <div className="mb-4 flex items-center justify-between gap-4">
              <h2 className="section-title">Upcoming assessments</h2>
              <Link
                className="flex items-center gap-1 text-sm text-primary hover:underline"
                href={ROUTES.ASSESSMENTS}
              >
                View all <ArrowRight aria-hidden className="h-3.5 w-3.5" />
              </Link>
            </div>

            {upcomingAssessments.length === 0 ? (
              <div className="empty-state">
                <Calendar aria-hidden className="h-10 w-10 text-muted-foreground" />
                <p className="text-muted-foreground">No upcoming assessments right now.</p>
              </div>
            ) : (
              <div className="flex flex-col gap-3">
                {upcomingAssessments.map((assessment) => (
                  <AssessmentRow assessment={assessment} key={assessment.id} />
                ))}
              </div>
            )}
          </section>
        </div>

        {/* Right rail */}
        <aside className="flex flex-col gap-8 lg:col-span-1">
          {/* Your batch widget */}
          {myBatches.length > 0 && (
            <section>
              <h2 className="subsection-title mb-4">
                {myBatches.length === 1 ? "Your batch" : "Your batches"}
              </h2>
              <div className="flex flex-col gap-2">
                {myBatches.map((batch) => (
                  <BatchWindowRow batch={batch} key={batch.id} />
                ))}
              </div>
            </section>
          )}

          {/* Upcoming events widget */}
          <section>
            <div className="mb-4 flex items-center justify-between gap-4">
              <h2 className="subsection-title">Upcoming</h2>
              <Link
                className="flex items-center gap-1 text-sm text-primary hover:underline"
                href={ROUTES.CALENDAR}
              >
                Calendar <ArrowRight aria-hidden className="h-3.5 w-3.5" />
              </Link>
            </div>
            {upcomingEvents.length === 0 ? (
              <div className="empty-state">
                <Calendar aria-hidden className="h-8 w-8 text-muted-foreground" />
                <p className="text-muted-foreground">Nothing on your calendar for the next {UPCOMING_EVENTS_WINDOW_DAYS} days.</p>
              </div>
            ) : (
              <div className="flex flex-col gap-2">
                {upcomingEvents.map((event) => (
                  <UpcomingEventRow event={event} key={event.id} />
                ))}
              </div>
            )}
          </section>

          {/* XP progress widget */}
          {rewardProfile && (
            <section className="card-base flex flex-col gap-4 p-5">
              <h2 className="subsection-title">Your Progress</h2>
              <XPProgressBar level={rewardProfile.level} totalXP={rewardProfile.total_xp} />
              {rewardProfile.achievements.length > 0 && (
                <div className="flex flex-wrap gap-1.5">
                  {rewardProfile.achievements.slice(0, 5).map((a) => (
                    <span
                      className="rounded-full border border-border bg-muted px-2 py-0.5 text-xs"
                      key={a.id}
                      title={a.definition.description}
                    >
                      {a.definition.icon} {a.definition.name}
                    </span>
                  ))}
                  {rewardProfile.achievements.length > 5 && (
                    <span className="rounded-full border border-border bg-muted px-2 py-0.5 text-xs text-muted-foreground">
                      +{rewardProfile.achievements.length - 5} more
                    </span>
                  )}
                </div>
              )}
            </section>
          )}

          {/* Leaderboard */}
          {leaderboardPreview.entries.length > 0 && (
            <section>
              <div className="mb-4 flex items-center justify-between gap-4">
                <h2 className="subsection-title">Leaderboard</h2>
                <Link
                  className="flex items-center gap-1 text-sm text-primary hover:underline"
                  href={ROUTES.LEADERBOARD}
                >
                  View all <ArrowRight aria-hidden className="h-3.5 w-3.5" />
                </Link>
              </div>
              <LeaderboardTable
                entries={leaderboardPreview.entries}
                myRank={leaderboardPreview.myRank}
                myUserID={user.id}
              />
            </section>
          )}
        </aside>
      </div>
    </main>
  );
}

// ─── Sub-components ────────────────────────────────────────────────────────────

interface BatchWindowRowProps {
  batch: MyBatch;
}

function BatchWindowRow({ batch }: BatchWindowRowProps) {
  const ending = batch.ends_at ? new Date(batch.ends_at) < new Date() : false;

  return (
    <div className="card-base flex items-center gap-3 p-3">
      <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary/10">
        <Calendar aria-hidden className="h-4 w-4 text-primary" />
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium">{batch.name}</p>
        <p className={`text-xs ${ending ? "text-destructive" : "text-muted-foreground"}`}>
          {formatBatchWindow(batch.starts_at, batch.ends_at)}
        </p>
      </div>
    </div>
  );
}

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
