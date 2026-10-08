import { notFound } from "next/navigation";
import { CheckCircle2, TrendingUp, Users } from "lucide-react";
import { getInstructorCourseBySlug } from "@/lib/server/courses";
import {
  getCourseAnalytics,
  getCourseStudents,
  getHardestQuestions,
} from "@/lib/server/course-analytics";
import { requireAccess } from "@/lib/server/features";
import { getMyPermissions } from "@/lib/server/permissions";
import { FEATURES } from "@/lib/features";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import {
  ANALYTICS_DEFAULT_DAYS,
  ANALYTICS_MAX_LIMIT,
  ANALYTICS_QUESTIONS_DEFAULT_LIMIT,
  ANALYTICS_STUDENTS_DEFAULT_LIMIT,
  AT_RISK_DEFAULT_INACTIVE_DAYS,
  AT_RISK_DEFAULT_PROGRESS_PCT,
} from "@/lib/constants";
import ROUTES from "@/lib/routes";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { AnalyticsFilters } from "@/components/courses/analytics/analytics-filters";
import { AtRiskStudentsTable } from "@/components/courses/analytics/at-risk-students-table";
import { EnrollmentTrendChart } from "@/components/courses/analytics/enrollment-trend-chart";
import { FunnelChart } from "@/components/courses/analytics/funnel-chart";
import { HardestQuestionsTable } from "@/components/courses/analytics/hardest-questions-table";
import { LessonDropoffTable } from "@/components/courses/analytics/lesson-dropoff-table";
import { StatTile } from "@/components/courses/analytics/stat-tile";

interface Props {
  params: Promise<{ slug: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}

export async function generateMetadata({ params }: Props) {
  const { slug } = await params;
  const course = await getInstructorCourseBySlug(slug).catch(() => undefined);
  return { title: course ? `${course.title} Analytics` : "Analytics" };
}

function intParam(raw: string | string[] | undefined, fallback: number, max: number): number {
  const n = Number.parseInt(Array.isArray(raw) ? raw[0] : (raw ?? ""), 10);
  return Number.isFinite(n) && n > 0 ? Math.min(n, max) : fallback;
}

export default async function CourseAnalyticsPage({ params, searchParams }: Props) {
  await requireAccess(FEATURES.COURSES);
  const [{ slug }, sp] = await Promise.all([params, searchParams]);
  const [myPerms, course] = await Promise.all([
    getMyPermissions(),
    getInstructorCourseBySlug(slug).catch(() => undefined),
  ]);
  if (!myPerms.includes(PERMISSIONS.COURSES.VIEW_ANALYTICS) || !course) {
    notFound();
  }

  const [analytics, questions, students] = await Promise.all([
    getCourseAnalytics(course.id, intParam(sp.days, ANALYTICS_DEFAULT_DAYS, ANALYTICS_MAX_LIMIT)),
    getHardestQuestions(course.id, intParam(sp.q_limit, ANALYTICS_QUESTIONS_DEFAULT_LIMIT, ANALYTICS_MAX_LIMIT)),
    getCourseStudents(course.id, {
      risk: "at_risk",
      inactiveDays: intParam(sp.inactive_days, AT_RISK_DEFAULT_INACTIVE_DAYS, ANALYTICS_MAX_LIMIT),
      maxProgressPct: intParam(sp.max_progress_pct, AT_RISK_DEFAULT_PROGRESS_PCT, 100),
      limit: intParam(sp.s_limit, ANALYTICS_STUDENTS_DEFAULT_LIMIT, ANALYTICS_MAX_LIMIT),
    }),
  ]);

  const { funnel } = analytics;
  const completionPct = funnel.enrolled > 0 ? Math.round((funnel.completed / funnel.enrolled) * 100) : 0;

  return (
    <main className="page-container">
      <Breadcrumb
        items={[
          { label: "Teach", href: ROUTES.TEACH },
          { label: course.title, href: ROUTES.courseEdit(slug) },
          { label: "Analytics" },
        ]}
      />

      <div className="page-header">
        <h1 className="section-title">{course.title} — Analytics</h1>
        <AnalyticsFilters />
      </div>

      <div className="grid-stats mb-8">
        <StatTile icon={Users} label="Enrolled" value={funnel.enrolled} />
        <StatTile icon={CheckCircle2} label="Completed" value={funnel.completed} />
        <StatTile highlight icon={TrendingUp} label="Completion rate" value={`${completionPct}%`} />
      </div>

      <div className="grid-responsive-2 mb-8">
        <section aria-labelledby="funnel-heading" className="card-base min-w-0 p-6">
          <h2 className="section-title mb-4" id="funnel-heading">Progress funnel</h2>
          <FunnelChart funnel={funnel} />
        </section>
        <section aria-labelledby="trend-heading" className="card-base min-w-0 p-6">
          <h2 className="section-title mb-4" id="trend-heading">Enrollments</h2>
          <EnrollmentTrendChart points={analytics.trend} />
        </section>
      </div>

      <section aria-labelledby="lessons-heading" className="card-base mb-8 p-6">
        <h2 className="section-title mb-4" id="lessons-heading">Lesson drop-off</h2>
        <LessonDropoffTable lessons={analytics.lessons} />
      </section>

      <section aria-labelledby="questions-heading" className="card-base mb-8 p-6">
        <h2 className="section-title mb-4" id="questions-heading">Hardest questions</h2>
        <HardestQuestionsTable data={questions} />
      </section>

      <section aria-labelledby="students-heading" className="card-base p-6">
        <h2 className="section-title mb-4" id="students-heading">At-risk students</h2>
        <AtRiskStudentsTable data={students} />
      </section>
    </main>
  );
}
