import type { Metadata } from "next";
import Link from "next/link";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import {
  Flame,
  BookOpen,
  Calendar,
  ClipboardCheck,
  ArrowRight,
  Brain,
  GraduationCap,
} from "lucide-react";

import { BrandMark } from "@/components/shared/brand-mark";
import { Button } from "@/components/ui/button";
import ROUTES from "@/lib/routes";
import { getEnrollments, getCourseProgress } from "@/lib/server/courses";
import { getMyAssessments } from "@/lib/server/assessments";
import { fetchMyProfile } from "@/lib/server/profile";
import { getDueCards } from "@/lib/server/srs";
import type { Enrollment, CourseProgressSummary } from "@/lib/server/courses";
import type { AssignedAssessment } from "@/lib/assessments/types";
import type { Profile } from "@/lib/profile/types";

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

async function fetchProfileData(): Promise<Profile | null> {
  try {
    return await fetchMyProfile();
  } catch {
    return null;
  }
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

  const [coursesWithProgress, upcomingAssessments, profile, dueCardsResult] = await Promise.all([
    fetchEnrolledCoursesWithProgress(),
    fetchUpcomingAssessments(),
    fetchProfileData(),
    getDueCards().catch(() => ({ cards: [], total: 0 })),
  ]);

  const streak = profile?.stats?.current_streak_days ?? 0;
  const dueCount = dueCardsResult.total;

  return (
    <main className="page-container py-10">
      <div className="mb-10 flex flex-col items-start gap-6 sm:flex-row sm:items-center sm:justify-between">
        <BrandMark />
        <p className="text-sm text-muted-foreground">{user.email}</p>
      </div>

      <div className="mb-8 flex flex-col gap-2">
        <h1>Welcome back, {firstName}</h1>
        <p className="text-muted-foreground">Here&apos;s your learning overview.</p>
      </div>

      {/* Stat row */}
      <div className="grid-stats mb-8">
        <StatCard
          icon={Flame}
          label="Day streak"
          value={String(streak)}
          unit={streak === 1 ? "day" : "days"}
          highlighted={streak > 0}
        />
        <StatCard
          icon={GraduationCap}
          label="Enrolled courses"
          value={String(profile?.stats?.courses_enrolled ?? coursesWithProgress.length)}
          unit="total"
        />
        <StatCard
          icon={ClipboardCheck}
          label="Tests attempted"
          value={String(profile?.stats?.tests_attempted ?? 0)}
          unit="total"
        />
        <StatCard
          icon={Brain}
          label="Review cards due"
          value={String(dueCount)}
          unit={dueCount === 1 ? "card" : "cards"}
          highlighted={dueCount > 0}
          href={ROUTES.REVIEW}
        />
      </div>

      {/* Enrolled courses */}
      <section className="mb-8">
        <div className="mb-4 flex items-center justify-between gap-4">
          <h2 className="section-title">Your courses</h2>
          <Link
            href={ROUTES.COURSES}
            className="flex items-center gap-1 text-sm text-primary hover:underline"
          >
            View all <ArrowRight className="h-3.5 w-3.5" aria-hidden />
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
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {coursesWithProgress.map(({ enrollment, progress }) => (
              <CourseCard
                key={enrollment.id}
                enrollment={enrollment}
                progress={progress}
              />
            ))}
          </div>
        )}
      </section>

      {/* Upcoming assessments */}
      <section className="mb-8">
        <div className="mb-4 flex items-center justify-between gap-4">
          <h2 className="section-title">Upcoming assessments</h2>
          <Link
            href={ROUTES.ASSESSMENTS}
            className="flex items-center gap-1 text-sm text-primary hover:underline"
          >
            View all <ArrowRight className="h-3.5 w-3.5" aria-hidden />
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
              <AssessmentRow key={assessment.id} assessment={assessment} />
            ))}
          </div>
        )}
      </section>
    </main>
  );
}

// ─── Sub-components ────────────────────────────────────────────────────────────

interface StatCardProps {
  icon: React.ElementType;
  label: string;
  value: string;
  unit: string;
  highlighted?: boolean;
  muted?: boolean;
  href?: string;
}

function StatCard({ icon: Icon, label, value, unit, highlighted = false, muted = false, href }: StatCardProps) {
  const inner = (
    <>
      <span
        className={`flex h-9 w-9 items-center justify-center rounded-md ${
          highlighted ? "bg-primary/10" : "bg-muted"
        }`}
      >
        <Icon
          aria-hidden
          className={`h-5 w-5 ${highlighted ? "text-primary" : "text-muted-foreground"}`}
        />
      </span>
      <div className="flex flex-col gap-0.5">
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className={`text-2xl font-bold tabular-nums ${muted ? "text-muted-foreground" : ""}`}>
          {value}
        </p>
        <p className="text-xs text-muted-foreground">{unit}</p>
      </div>
    </>
  );

  if (href) {
    return (
      <Link href={href} className="card-interactive flex flex-col gap-3 p-5">
        {inner}
      </Link>
    );
  }

  return (
    <div className="card-base flex flex-col gap-3 p-5">
      {inner}
    </div>
  );
}

interface CourseCardProps {
  enrollment: Enrollment;
  progress: CourseProgressSummary | null;
}

function CourseCard({ enrollment, progress }: CourseCardProps) {
  const pct = progress?.pct ?? 0;
  const completed = progress?.completed ?? 0;
  const total = progress?.total ?? 0;

  return (
    <Link
      href={ROUTES.courseLearn(enrollment.course.slug)}
      className="card-interactive flex flex-col gap-4 p-5"
    >
      <div className="flex flex-col gap-1">
        <h3 className="line-clamp-2 text-sm font-semibold leading-snug">
          {enrollment.course.title}
        </h3>
        {enrollment.course.difficulty && (
          <span className={`difficulty-${enrollment.course.difficulty} self-start text-xs`}>
            {enrollment.course.difficulty}
          </span>
        )}
      </div>

      <div className="mt-auto flex flex-col gap-1.5">
        <div className="flex items-center justify-between text-xs text-muted-foreground">
          <span>{completed} / {total} modules</span>
          <span className="font-medium tabular-nums">{Math.round(pct)}%</span>
        </div>
        <div className="progress-track h-1.5">
          {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width requires inline style */}
          <div
            className="progress-fill h-full bg-primary"
            style={{ width: `${pct}%` }}
            aria-hidden
          />
        </div>
      </div>
    </Link>
  );
}

interface AssessmentRowProps {
  assessment: AssignedAssessment;
}

function AssessmentRow({ assessment }: AssessmentRowProps) {
  const dueDateLabel = formatDueDate(assessment.ends_at);
  const isOverdue = assessment.ends_at && new Date(assessment.ends_at) < new Date();
  const attemptsLeft = assessment.max_attempts - assessment.attempts_used;

  return (
    <Link
      href={ROUTES.assessment(assessment.id)}
      className="card-interactive flex items-center gap-4 p-4"
    >
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
    </Link>
  );
}
