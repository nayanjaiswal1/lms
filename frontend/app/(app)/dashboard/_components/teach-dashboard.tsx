import Link from "next/link";
import { BookOpen } from "lucide-react";
import { Suspense } from "react";

import { EnrollmentTrendChart } from "@/components/courses/analytics/enrollment-trend-chart";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { PageHeader } from "@/components/shared/page-header";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";
import { getOrgAnalytics } from "@/lib/assessments/server";
import { getOrgCourseSummaries, getOrgEnrollmentTrend } from "@/lib/server/course-analytics";
import { DashboardEmptyState } from "./empty-state";
import { GradingQueue } from "./grading-queue";
import { DashboardSectionHeader } from "./section-header";
import { ListSkeleton, StatTiles, StatTilesSkeleton } from "./stat-tiles";

const COURSES_LIMIT = 6;
const TREND_DAYS = 30;

async function AssessmentStats() {
  const stats = await getOrgAnalytics().catch(() => null);
  if (!stats) return null;
  return (
    <StatTiles
      tiles={[
        { label: "Assessments", value: stats.total_assessments },
        { label: "Questions", value: stats.total_questions },
        { label: "Attempts", value: stats.total_attempts },
        { label: "Avg pass rate", value: `${Math.round(stats.avg_pass_rate)}%` },
      ]}
    />
  );
}

async function CourseSummaries({ mine }: { mine: boolean }) {
  const summaries = await getOrgCourseSummaries(COURSES_LIMIT, mine).catch(() => null);
  if (!summaries || summaries.courses.length === 0) {
    return (
      <DashboardEmptyState
        action={{ href: ROUTES.COURSE_NEW, label: "Create a course" }}
        icon={BookOpen}
        message={mine ? "No courses to report on yet." : "No org courses to report on yet."}
      />
    );
  }
  return (
    <div className="grid gap-4 sm:grid-cols-2">
      {summaries.courses.map((c) => (
        <Link className="card-base card-interactive flex min-w-0 flex-col gap-2 p-6" href={ROUTES.courseEditAnalytics(c.slug)} key={c.course_id}>
          <span className="truncate font-medium">{c.title}</span>
          <span className="text-sm text-muted-foreground">
            {c.enrolled} enrolled · {c.completed} completed · {Math.round(c.avg_progress_pct)}% avg progress
          </span>
        </Link>
      ))}
    </div>
  );
}

async function TrendCard() {
  const points = await getOrgEnrollmentTrend(TREND_DAYS).catch(() => null);
  if (!points) return null;
  return (
    <section aria-labelledby="teach-trend" className="card-base p-6">
      <h2 className="section-title mb-4" id="teach-trend">Enrollments, last {TREND_DAYS} days</h2>
      <EnrollmentTrendChart points={points} />
    </section>
  );
}

interface TeachDashboardProps {
  firstName: string;
  perms: readonly string[];
}

export function TeachDashboard({ firstName, perms }: TeachDashboardProps) {
  const can = (code: string) => perms.includes(code);
  return (
    <main className="page-container">
      <PageHeader description="Your courses, learners and assessments." title={`Welcome back, ${firstName}`}>
        <div className="flex flex-wrap gap-2">
          <Button asChild size="sm"><Link href={ROUTES.COURSE_NEW}>New course</Link></Button>
          {can(PERMISSIONS.ASSESSMENTS.MANAGE_QUESTIONS) && (
            <Button asChild size="sm" variant="outline"><Link href={ROUTES.QUESTION_BANK}>Question bank</Link></Button>
          )}
          {can(PERMISSIONS.ASSESSMENTS.CREATE) && (
            <Button asChild size="sm" variant="outline"><Link href={ROUTES.ASSESSMENT_NEW}>New assessment</Link></Button>
          )}
        </div>
      </PageHeader>

      <div className="flex flex-col gap-8">
        {can(PERMISSIONS.ASSESSMENTS.VIEW_RESULTS) && (
          <>
            <Suspense fallback={<StatTilesSkeleton />}>
              <AssessmentStats />
            </Suspense>
            <section>
              <DashboardSectionHeader title="Awaiting review" />
              <Suspense fallback={<ListSkeleton />}>
                <GradingQueue />
              </Suspense>
            </section>
          </>
        )}

        {can(PERMISSIONS.COURSES.VIEW_ANALYTICS) && (
          <>
            <section>
              <DashboardSectionHeader link={{ href: ROUTES.TEACH_ANALYTICS, label: "Analytics" }} title="My courses" />
              <Suspense fallback={<ListSkeleton />}>
                <CourseSummaries mine />
              </Suspense>
            </section>
            {can(PERMISSIONS.ADMIN.MANAGE_ORG) && (
              <section>
                <DashboardSectionHeader title="Org courses" />
                <Suspense fallback={<ListSkeleton />}>
                  <CourseSummaries mine={false} />
                </Suspense>
              </section>
            )}
            <Suspense fallback={<Skeleton className="h-64" />}>
              <TrendCard />
            </Suspense>
          </>
        )}
      </div>
    </main>
  );
}
